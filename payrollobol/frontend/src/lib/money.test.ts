import { describe, it, expect } from 'vitest'
import { cents, decimal, money, summarize, balance, departments } from './money'
import { demoSnapshot } from './demo'
import { snapshotSchema } from './models'

describe('exact decimal presentation', () => {
  it('preserves cents and values above Number precision', () => {
    expect(cents('000001.01')).toBe(101n)
    expect(money('900719925474099.91')).toBe('$900,719,925,474,099.91')
    expect(decimal(-1n)).toBe('-0.01')
    expect(money(-120n)).toBe('-$1.20')
    expect(() => cents('1.001')).toThrow()
  })
  it('aggregates supplied amounts without calculating payroll', () => {
    const snapshot = snapshotSchema.parse(demoSnapshot())
    const totals = summarize(snapshot.employees)
    expect(totals).toMatchObject({ count: 3, gross: 451875n, tax: 138576n, net: 313299n })
    expect(balance(snapshot)).toEqual({ debit: 451875n, credit: 451875n, difference: 0n, balanced: true })
    expect(departments(snapshot.employees)[0]).toMatchObject({ name: 'ENG', count: 2, gross: 346875n })
  })
  it('handles empty output and detects imbalance', () => {
    expect(summarize([]).count).toBe(0)
    const snapshot = demoSnapshot()
    snapshot.ledger[0].debit = '1543.76'
    expect(balance(snapshot).difference).toBe(1n)
    expect(balance(snapshot).balanced).toBe(false)
  })
})
