import { mkdtempSync, mkdirSync, copyFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'
import { createServer } from 'vite'

const project = fileURLToPath(new URL('../../', import.meta.url))
const work = path.join(project, 'tests/.work')
mkdirSync(work, { recursive: true })
const root = mkdtempSync(path.join(work, 'browser-'))
for (const directory of ['bin', 'data/input', 'data/output']) mkdirSync(path.join(root, directory), { recursive: true })
copyFileSync(path.join(project, 'schema.sql'), path.join(root, 'schema.sql'))
copyFileSync(path.join(project, 'bin/payrollobol.exe'), path.join(root, 'bin/payrollobol.exe'))
const pathKey = Object.keys(process.env).find(key => key.toLowerCase() === 'path') ?? 'PATH'
const environment = { ...process.env, [pathKey]: [path.join(project, '.tools/mingw64/bin'),
  path.join(process.env.MINGW_HOME || 'C:/mingw64', 'bin'), process.env[pathKey]].join(path.delimiter) }
execFileSync(path.join(project, 'bin/seed_data.exe'), { cwd: root, env: environment })
process.env.PAYROLLOBOL_ROOT = root
const server = await createServer({ server: { host: '127.0.0.1', port: 5180, strictPort: true } })
await server.listen()
console.log('Isolated browser fixture:', root)
server.printUrls()