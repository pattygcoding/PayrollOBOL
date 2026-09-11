PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS general_ledger (
    entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
    pay_period TEXT NOT NULL,
    emp_id INTEGER NOT NULL,
    account_code TEXT NOT NULL,
    debit_amount DECIMAL(10,2) DEFAULT 0.00,
    credit_amount DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ledger_period ON general_ledger(pay_period);
CREATE INDEX IF NOT EXISTS idx_ledger_emp ON general_ledger(emp_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_ledger_once
    ON general_ledger(pay_period, emp_id, account_code);
CREATE TABLE IF NOT EXISTS payroll_runs (
    pay_period TEXT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
