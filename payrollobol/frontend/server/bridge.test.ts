import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { mkdtemp, mkdir, copyFile, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'
import { DatabaseSync } from 'node:sqlite'
import { get } from 'node:http'
import { createServer, type ViteDevServer } from 'vite'
import { loadLocalSnapshot, localPayrollPlugin } from './bridge.ts'
import { balance, summarize } from '../src/lib/money.ts'

const project = fileURLToPath(new URL('../../', import.meta.url))
const pathKey = Object.keys(process.env).find(key => key.toLowerCase() === 'path') ?? 'PATH'
const environment = { ...process.env, [pathKey]: [path.join(project, '.tools/mingw64/bin'),
  path.join(process.env.MINGW_HOME || 'C:/mingw64', 'bin'), process.env[pathKey]].join(path.delimiter) }
let root: string
let server: ViteDevServer | undefined
function execute(name: string) { execFileSync(path.join(project, 'bin', `${name}.exe`), { cwd: root, env: environment }) }
beforeEach(async () => {
  root = await mkdtemp(path.join(tmpdir(), 'payrollobol-bridge-'))
  await mkdir(path.join(root, 'data/input'), { recursive: true })
  await mkdir(path.join(root, 'data/output'), { recursive: true })
  await mkdir(path.join(root, 'bin'))
  await copyFile(path.join(project, 'schema.sql'), path.join(root, 'schema.sql'))
})
afterEach(async () => { await server?.close(); server = undefined; await rm(root, { recursive: true, force: true }) })
async function ready() {
  await copyFile(path.join(project, 'bin/payrollobol.exe'), path.join(root, 'bin/payrollobol.exe'))
  execute('seed_data')
}
async function endpoint() {
  server = await createServer({ configFile: false, plugins: [localPayrollPlugin(root)], server: { host: '127.0.0.1', port: 0 } })
  await server.listen()
  const address = server.httpServer!.address()
  if (!address || typeof address === 'string') throw new Error('Missing test server port')
  return `http://127.0.0.1:${address.port}/api/payroll`
}
describe('real local payroll bridge', () => {
  it('reports empty and ready states without fabricating results', async () => {
    expect(await loadLocalSnapshot(root)).toMatchObject({ status: 'empty', canRun: false, employees: [] })
    await ready()
    expect(await loadLocalSnapshot(root)).toMatchObject({ status: 'ready', canRun: true, inputPeriod: '20260915', employees: [] })
  })
  it('loads exact published results and reconciles every ledger entry', async () => {
    await ready(); execute('payrollobol')
    const snapshot = await loadLocalSnapshot(root)
    expect(snapshot.status).toBe('posted')
    expect(snapshot.canRun).toBe(false)
    expect(summarize(snapshot.employees)).toMatchObject({ gross: 451875n, tax: 138576n, net: 313299n })
    expect(balance(snapshot)).toMatchObject({ debit: 451875n, credit: 451875n, balanced: true })
    expect(snapshot.report).toContain('GRAND TOTAL')
  })
  it('rejects partial cards and pending publication', async () => {
    await writeFile(path.join(root, 'data/input/timecards.dat'), '100101')
    await expect(loadLocalSnapshot(root)).rejects.toThrow('32-byte')
    await writeFile(path.join(root, 'data/output/publication.pending'), '20260915')
    await expect(loadLocalSnapshot(root)).rejects.toThrow('recovery required')
  })
  it('rejects ledger corruption instead of displaying trusted totals', async () => {
    await ready(); execute('payrollobol')
    const database = new DatabaseSync(path.join(root, 'data/payroll.db'))
    database.exec("UPDATE general_ledger SET credit_amount = 1.00 WHERE emp_id = 100101 AND account_code = '2101'")
    database.close()
    await expect(loadLocalSnapshot(root)).rejects.toThrow('does not reconcile')
  })
  it('rejects impossible calendar dates before rendering the dashboard', async () => {
    await ready()
    await writeFile(path.join(root, 'data/input/timecards.dat'), '1001014000050020260230          ')
    await expect(loadLocalSnapshot(root)).rejects.toThrow('Invalid calendar pay period')
  })
  it('requires same-origin POST with a local request header', async () => {
    const url = await endpoint()
    expect((await fetch(`${url}/run`)).status).toBe(405)
    expect((await fetch(`${url}/run`, { method: 'POST' })).status).toBe(403)
    expect((await fetch(url, { headers: { Origin: 'https://example.com' } })).status).toBe(403)
    const hostileHostStatus = await new Promise<number | undefined>((resolve, reject) => {
      get(url, { headers: { Host: 'example.com' } }, response => {
        response.resume()
        resolve(response.statusCode)
      }).on('error', reject)
    })
    expect(hostileHostStatus).toBe(403)
    expect((await fetch(url)).status).toBe(200)
  })
  it('runs the native batch once through HTTP and rejects a replay', async () => {
    await ready()
    const url = await endpoint()
    const options = { method: 'POST', headers: { 'X-Payroll-Request': '1' } }
    const response = await fetch(`${url}/run`, options)
    expect(response.status).toBe(200)
    expect(await response.json()).toMatchObject({ status: 'posted', canRun: false })
    expect((await fetch(`${url}/run`, options)).status).toBe(409)
  })
})