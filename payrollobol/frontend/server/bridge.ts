import { readFile, stat, open } from 'node:fs/promises'
import { existsSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { DatabaseSync } from 'node:sqlite'
import { parse } from 'csv-parse/sync'
import type { IncomingMessage, ServerResponse } from 'node:http'
import type { Plugin } from 'vite'
import { employeeSchema, ledgerSchema, snapshotSchema, type PayrollSnapshot } from '../src/lib/models.ts'
import { cents } from '../src/lib/money.ts'

const execute = promisify(execFile)
const defaultRoot = fileURLToPath(new URL('../../', import.meta.url))

export async function loadLocalSnapshot(root: string): Promise<PayrollSnapshot> {
  const output = path.join(root, 'data/output')
  const pending = path.join(output, 'publication.pending')
  if (existsSync(pending)) throw new Error('Publication recovery required. Review data/output/publication.pending before running payroll.')
  let inputPeriod: string | null = null
  const cardPath = path.join(root, 'data/input/timecards.dat')
  if (existsSync(cardPath)) {
    const file = await open(cardPath, 'r')
    try {
      const information = await file.stat()
      if (information.size % 32 !== 0) throw new Error('Time cards must contain complete 32-byte records.')
      if (information.size > 0) {
        const buffer = Buffer.alloc(22)
        await file.read(buffer, 0, 22, 0)
        inputPeriod = buffer.toString('ascii', 14, 22)
        if (!/^\d{8}$/.test(inputPeriod)) throw new Error('Invalid input pay period.')
      }
    } finally { await file.close() }
  }
  const resultPath = path.join(output, 'results.psv')
  const hasResults = existsSync(resultPath)
  const employees = hasResults
    ? employeeSchema.array().parse(parse(await readFile(resultPath, 'utf8'), { columns: true, delimiter: '|', skip_empty_lines: true, trim: true }))
    : []
  const period = employees[0]?.period ?? null
  if (employees.some(employee => employee.period !== period)) throw new Error('Result file contains mixed pay periods.')
  if (new Set(employees.map(employee => employee.id)).size !== employees.length) throw new Error('Result file contains duplicate employees.')
  let posted = false
  let ledger: PayrollSnapshot['ledger'] = []
  const databasePath = path.join(root, 'data/payroll.db')
  if (existsSync(databasePath)) {
    const database = new DatabaseSync(databasePath, { readOnly: true })
    try {
      if (inputPeriod) posted = Boolean(database.prepare('SELECT 1 FROM payroll_runs WHERE pay_period = ?').get(inputPeriod))
      if (period) {
        ledger = ledgerSchema.array().parse(database.prepare(`SELECT printf('%06d',emp_id) AS employeeId,
          account_code AS account, printf('%.2f',debit_amount) AS debit,
          printf('%.2f',credit_amount) AS credit FROM general_ledger WHERE pay_period = ? ORDER BY entry_id`).all(period))
      }
    } finally { database.close() }
  }
  if (employees.length > 0) {
    if (ledger.length !== employees.length * 5) throw new Error('Ledger row count does not match the published results.')
    const amounts = { '5001': 'gross', '2101': 'federal', '2102': 'state', '2103': 'fica', '1001': 'net' } as const
    for (const employee of employees) {
      for (const [account, field] of Object.entries(amounts)) {
        const entries = ledger.filter(entry => entry.employeeId === employee.id && entry.account === account)
        if (entries.length !== 1 || cents(entries[0].debit) !== (account === '5001' ? cents(employee[field]) : 0n)
          || cents(entries[0].credit) !== (account !== '5001' ? cents(employee[field]) : 0n)) {
          throw new Error(`Ledger does not reconcile for employee ${employee.id}, account ${account}.`)
        }
      }
    }
  }
  const report = hasResults ? await readFile(path.join(output, 'payroll_report.txt'), 'utf8') : ''
  if (existsSync(pending)) throw new Error('Payroll output is being published. Refresh after the batch completes.')
  const binary = existsSync(path.join(root, 'bin/payrollobol.exe'))
  const inputReady = Boolean(inputPeriod) && existsSync(path.join(root, 'data/input/emp_master.dat'))
  return snapshotSchema.parse({
    source: 'local', status: posted ? 'posted' : inputReady ? 'ready' : 'empty',
    period, inputPeriod, generatedAt: hasResults ? (await stat(resultPath)).mtime.toISOString() : null,
    canRun: binary && inputReady && !posted,
    reason: !binary ? 'Batch executable not found. Run build.bat.'
      : !inputReady ? 'No complete input batch. Seed or supply employee and time-card files.'
      : posted ? 'This pay period is already posted. Duplicate posting is blocked.'
      : 'Input batch ready for processing.',
    employees, ledger, report,
  })
}

export function localPayrollPlugin(root = process.env.PAYROLLOBOL_ROOT || defaultRoot): Plugin {
  let running = false
  async function middleware(request: IncomingMessage, response: ServerResponse, next: () => void) {
    const route = request.url?.split('?')[0]
    if (!route?.startsWith('/api/payroll')) return next()
    response.setHeader('Content-Type', 'application/json; charset=utf-8')
    response.setHeader('Cache-Control', 'no-store')
    response.setHeader('X-Content-Type-Options', 'nosniff')
    const reply = (status: number, body: unknown) => { response.statusCode = status; response.end(JSON.stringify(body)) }
    const host = request.headers.host ?? ''
    if (!/^(localhost|127\.0\.0\.1)(:\d+)?$/.test(host)
      || !['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(request.socket.remoteAddress ?? '')
      || (request.headers.origin && request.headers.origin !== `http://${host}`)) {
      return reply(403, { error: 'Only same-origin loopback requests are allowed.' })
    }
    try {
      if (route === '/api/payroll' && request.method === 'GET') {
        if (running) return reply(409, { error: 'A payroll batch is running. Refresh after it completes.' })
        return reply(200, await loadLocalSnapshot(root))
      }
      if (route !== '/api/payroll/run') return reply(404, { error: 'Unknown payroll endpoint.' })
      if (request.method !== 'POST') return reply(405, { error: 'Payroll execution requires POST.' })
      if (request.headers['x-payroll-request'] !== '1') return reply(403, { error: 'Missing local request header.' })
      if (running) return reply(409, { error: 'A payroll batch is already running.' })
      running = true
      try {
        const before = await loadLocalSnapshot(root)
        if (!before.canRun) return reply(409, { error: before.reason })
        const pathKey = Object.keys(process.env).find(key => key.toLowerCase() === 'path') ?? 'PATH'
        const environment = { ...process.env }
        environment[pathKey] = [path.join(defaultRoot, '.tools/mingw64/bin'),
          path.join(process.env.MINGW_HOME || 'C:/mingw64', 'bin'), process.env[pathKey]].join(path.delimiter)
        await execute(path.join(root, 'bin/payrollobol.exe'), [], {
          cwd: root, env: environment, windowsHide: true, timeout: 300000, maxBuffer: 1024 * 1024,
        })
        return reply(200, await loadLocalSnapshot(root))
      } finally { running = false }
    } catch (error) {
      const failure = error as Error & { stdout?: string; stderr?: string }
      reply(500, { error: failure.stdout?.trim() || failure.stderr?.trim() || failure.message })
    }
  }
  return {
    name: 'local-payroll-adapter',
    configureServer(server) { server.middlewares.use(middleware) },
    configurePreviewServer(server) { server.middlewares.use(middleware) },
  }
}
