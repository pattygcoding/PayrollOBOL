import { z } from 'zod'

export const decimalSchema = z.string().regex(/^\d{1,15}\.\d{2}$/)
const calendarDateSchema = z.iso.date()
const periodSchema = z.string().regex(/^\d{8}$/).refine(value => calendarDateSchema.safeParse(
  `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`,
).success, 'Invalid calendar pay period')
export const employeeSchema = z.object({
  period: periodSchema,
  id: z.string().regex(/^\d{6}$/),
  lastName: z.string().max(15),
  firstName: z.string().max(15),
  department: z.string().min(1).max(4),
  regularHours: decimalSchema,
  overtimeHours: decimalSchema,
  regularPay: decimalSchema,
  overtimePay: decimalSchema,
  gross: decimalSchema,
  federal: decimalSchema,
  state: decimalSchema,
  fica: decimalSchema,
  net: decimalSchema,
})
export const ledgerSchema = z.object({
  employeeId: z.string().regex(/^\d{6}$/),
  account: z.enum(['5001', '2101', '2102', '2103', '1001']),
  debit: decimalSchema,
  credit: decimalSchema,
})
export const snapshotSchema = z.object({
  source: z.enum(['local', 'demo']),
  status: z.enum(['empty', 'ready', 'posted']),
  period: periodSchema.nullable(),
  inputPeriod: periodSchema.nullable(),
  generatedAt: z.string().nullable(),
  canRun: z.boolean(),
  reason: z.string(),
  employees: z.array(employeeSchema),
  ledger: z.array(ledgerSchema),
  report: z.string(),
})
export type EmployeeResult = z.infer<typeof employeeSchema>
export type LedgerEntry = z.infer<typeof ledgerSchema>
export type PayrollSnapshot = z.infer<typeof snapshotSchema>
export type DataSource = PayrollSnapshot['source']
export type AccountCode = LedgerEntry['account']
export const accounts: Record<AccountCode, string> = {
  '5001': 'Gross payroll expense',
  '2101': 'Federal withholding',
  '2102': 'State withholding',
  '2103': 'FICA payable',
  '1001': 'Cash clearing',
}
