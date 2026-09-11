import type { PayrollSnapshot, EmployeeResult, LedgerEntry } from './models'

const employees: EmployeeResult[] = [
  { period: '20260915', id: '100101', lastName: 'Morgan', firstName: 'Alex', department: 'ENG', regularHours: '40.00', overtimeHours: '5.00', regularPay: '1300.00', overtimePay: '243.75', gross: '1543.75', federal: '279.63', state: '77.19', fica: '118.10', net: '1068.83' },
  { period: '20260915', id: '100102', lastName: 'Chen', firstName: 'Jordan', department: 'OPS', regularHours: '37.50', overtimeHours: '0.00', regularPay: '1050.00', overtimePay: '0.00', gross: '1050.00', federal: '171.00', state: '52.50', fica: '80.33', net: '746.17' },
  { period: '20260915', id: '100103', lastName: 'Patel', firstName: 'Sam', department: 'ENG', regularHours: '40.00', overtimeHours: '10.00', regularPay: '1400.00', overtimePay: '525.00', gross: '1925.00', federal: '363.50', state: '96.25', fica: '147.26', net: '1317.99' },
]
const ledger: LedgerEntry[] = employees.flatMap(employee => [
  { employeeId: employee.id, account: '5001', debit: employee.gross, credit: '0.00' },
  { employeeId: employee.id, account: '2101', debit: '0.00', credit: employee.federal },
  { employeeId: employee.id, account: '2102', debit: '0.00', credit: employee.state },
  { employeeId: employee.id, account: '2103', debit: '0.00', credit: employee.fica },
  { employeeId: employee.id, account: '1001', debit: '0.00', credit: employee.net },
])
export function demoSnapshot(): PayrollSnapshot {
  return structuredClone({
    source: 'demo', status: 'posted', period: '20260915', inputPeriod: '20260915',
    generatedAt: '2026-09-15T09:00:00Z', canRun: true,
    reason: 'Demo dataset. No payroll records will be posted.',
    employees, ledger,
    report: `PayrollOBOL | DEMO PAYROLL REGISTER | PAGE 0001 | RUN 2026-09-15 09:00:00
EMP ID  NAME                            DEPT  REG HRS OT HRS       GROSS       TAXES         NET
------------------------------------------------------------------------------------------------
100101  Morgan          Alex            ENG    40.00   5.00   $1,543.75     $474.92   $1,068.83
100103  Patel           Sam             ENG    40.00  10.00   $1,925.00     $607.01   $1,317.99
DEPARTMENT ENG | EMPLOYEES 000002 | GROSS $3,468.75 | TAXES $1,081.93 | NET $2,386.82

100102  Chen            Jordan          OPS    37.50   0.00   $1,050.00     $303.83     $746.17
DEPARTMENT OPS | EMPLOYEES 000001 | GROSS $1,050.00 | TAXES $303.83 | NET $746.17

GRAND TOTAL | EMPLOYEES 000003 | GROSS $4,518.75 | TAXES $1,385.76 | NET $3,132.99
BALANCED | DEBITS $4,518.75 = CREDITS $4,518.75
`,
  })
}
