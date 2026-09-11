import { snapshotSchema, type DataSource, type PayrollSnapshot } from './models'
import { demoSnapshot } from './demo'

async function request(path: string, method = 'GET'): Promise<PayrollSnapshot> {
  const response = await fetch(path, {
    method, cache: 'no-store',
    headers: { Accept: 'application/json', 'X-Payroll-Request': '1' },
  })
  if (!response.headers.get('content-type')?.includes('application/json')) {
    throw new Error('Local batch adapter is unavailable. Start the Vite server or select Demo data.')
  }
  const body: unknown = await response.json()
  if (!response.ok) {
    const message = body && typeof body === 'object' && 'error' in body ? String(body.error) : `Request failed (${response.status})`
    throw new Error(message)
  }
  return snapshotSchema.parse(body)
}
export const payrollAdapter = {
  load: (source: DataSource) => source === 'demo' ? Promise.resolve(demoSnapshot()) : request('/api/payroll'),
  run: (source: DataSource) => source === 'demo' ? Promise.resolve(demoSnapshot()) : request('/api/payroll/run', 'POST'),
}
