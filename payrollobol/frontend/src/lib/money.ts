import type { EmployeeResult, PayrollSnapshot } from './models.ts'

export function cents(value: string): bigint {
  if (!/^\d+\.\d{2}$/.test(value)) throw new Error(`Invalid decimal amount: ${value}`)
  return BigInt(value.replace('.', ''))
}
export function decimal(value: bigint): string {
  const negative = value < 0n
  const digits = (negative ? -value : value).toString().padStart(3, '0')
  return `${negative ? '-' : ''}${digits.slice(0, -2)}.${digits.slice(-2)}`
}
export function money(value: string | bigint): string {
  const amount = typeof value === 'string' ? cents(value) : value
  const [whole, fraction] = decimal(amount < 0n ? -amount : amount).split('.')
  return `${amount < 0n ? '-' : ''}$${whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}.${fraction}`
}
export function taxes(employee: EmployeeResult): bigint {
  return cents(employee.federal) + cents(employee.state) + cents(employee.fica)
}
export function summarize(employees: EmployeeResult[]) {
  return employees.reduce((total, employee) => ({
    count: total.count + 1,
    gross: total.gross + cents(employee.gross),
    tax: total.tax + taxes(employee),
    net: total.net + cents(employee.net),
    regular: total.regular + cents(employee.regularHours),
    overtime: total.overtime + cents(employee.overtimeHours),
  }), { count: 0, gross: 0n, tax: 0n, net: 0n, regular: 0n, overtime: 0n })
}
export function departments(employees: EmployeeResult[]) {
  const groups = new Map<string, EmployeeResult[]>()
  for (const employee of employees) {
    const group = groups.get(employee.department) ?? []
    group.push(employee)
    groups.set(employee.department, group)
  }
  return [...groups].sort(([left], [right]) => left.localeCompare(right))
    .map(([name, rows]) => ({ name, ...summarize(rows) }))
}
export function balance(snapshot: PayrollSnapshot | null) {
  const debit = snapshot?.ledger.reduce((total, entry) => total + cents(entry.debit), 0n) ?? 0n
  const credit = snapshot?.ledger.reduce((total, entry) => total + cents(entry.credit), 0n) ?? 0n
  return { debit, credit, difference: debit - credit, balanced: debit === credit }
}
export function share(value: bigint, total: bigint): number {
  return total === 0n ? 0 : Number(value * 10000n / total) / 100
}
export function periodLabel(period: string | null): string {
  if (!period) return 'No pay period'
  const date = new Date(`${period.slice(0, 4)}-${period.slice(4, 6)}-${period.slice(6, 8)}T12:00:00Z`)
  return new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' }).format(date)
}
