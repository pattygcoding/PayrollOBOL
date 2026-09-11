import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, copyFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const work = path.join(root, 'tests/.work');
const expected = JSON.parse(readFileSync(path.join(root, 'tests/fixtures/expected.json'), 'utf8'));
let failures = 0;
let checks = 0;

function test(name, callback) {
  try { callback(); checks++; console.log(`PASS ${name}`); }
  catch (error) { failures++; console.error(`FAIL ${name}\n${error.stack}`); }
}
function run(program, cwd, success = true) {
  const result = spawnSync(path.join(work, `${program}.exe`), [], { cwd, encoding: 'utf8', timeout: 20000 });
  assert.equal(result.error, undefined, `process error: ${result.error}`);
  if (success) assert.equal(result.status, 0, `expected success, actual ${result.status}\n${result.stdout}${result.stderr}`);
  else assert.notEqual(result.status, 0, `expected failure, actual success\n${result.stdout}`);
  return result.stdout;
}
function fixture(seed = true) {
  const directory = mkdtempSync(path.join(work, 'run-'));
  mkdirSync(path.join(directory, 'data/input'), { recursive: true });
  mkdirSync(path.join(directory, 'data/output'));
  copyFileSync(path.join(root, 'schema.sql'), path.join(directory, 'schema.sql'));
  if (seed) run('seed_data', directory);
  return directory;
}
const inputPath = (directory, name) => path.join(directory, `data/input/${name}.dat`);
const outputPath = (directory, name) => path.join(directory, `data/output/${name}`);
function readLedger(directory) {
  const database = new DatabaseSync(path.join(directory, 'data/payroll.db'));
  try {
    return database.prepare(`SELECT pay_period, emp_id, account_code,
      printf('%.2f', debit_amount) AS debit, printf('%.2f', credit_amount) AS credit
      FROM general_ledger ORDER BY emp_id, account_code`).all();
  } finally { database.close(); }
}
function cents(value) { return BigInt(value.replace('.', '')); }
function rejection(name, change, message) {
  test(name, () => {
    const directory = fixture();
    const sentinel = Buffer.from('previous published generation');
    writeFileSync(outputPath(directory, 'emp_master_new.dat'), sentinel);
    change(directory);
    const output = run('payrollobol', directory, false);
    assert.match(output, message);
    assert.deepEqual(readFileSync(outputPath(directory, 'emp_master_new.dat')), sentinel);
    assert.equal(readLedger(directory).length, 0, 'rollback must leave zero ledger entries');
    assert.equal(existsSync(outputPath(directory, 'publication.pending')), false);
  });
}

test('binary seed has exact 100/32 byte records and refuses overwrite', () => {
  const directory = fixture();
  assert.equal(readFileSync(inputPath(directory, 'emp_master')).length, 300);
  assert.equal(readFileSync(inputPath(directory, 'timecards')).length, 96);
  assert.match(run('seed_data', directory, false), /refuses to overwrite/);
});

test('COBOL DB entries, commit, rollback, reopen, and clean close', () => {
  const directory = fixture(false);
  run('test_db', directory);
  const rows = readLedger(directory);
  assert.equal(rows.length, 5);
  assert.deepEqual(rows.map(row => [row.account_code, row.debit, row.credit]), [
    ['1001', '0.00', '386.75'], ['2101', '0.00', '50.00'], ['2102', '0.00', '25.00'],
    ['2103', '0.00', '38.25'], ['5001', '500.00', '0.00'],
  ]);
  assert.ok(rows.every(row => row.pay_period === '20260915'));
});

test('end-to-end master, all five accounts, exact totals, report, replay safety', () => {
  const directory = fixture();
  const original = readFileSync(inputPath(directory, 'emp_master'));
  run('payrollobol', directory);
  run('verify_master', directory);
  assert.deepEqual(readFileSync(inputPath(directory, 'emp_master')), original);
  const rows = readLedger(directory);
  assert.equal(rows.length, 15);
  for (const employee of expected.employees) {
    const actual = rows.filter(row => row.emp_id === Number(employee.id));
    assert.deepEqual(actual.map(row => [row.account_code, row.debit, row.credit]), [
      ['1001', '0.00', employee.net], ['2101', '0.00', employee.federal],
      ['2102', '0.00', employee.state], ['2103', '0.00', employee.fica],
      ['5001', employee.gross, '0.00'],
    ]);
  }
  const debit = rows.reduce((sum, row) => sum + cents(row.debit), 0n);
  const credit = rows.reduce((sum, row) => sum + cents(row.credit), 0n);
  assert.equal(debit, cents(expected.gross));
  assert.equal(credit, debit);
  const report = readFileSync(outputPath(directory, 'payroll_report.txt'), 'utf8');
  for (const column of ['EMP ID', 'NAME', 'DEPT', 'REG HRS', 'OT HRS', 'GROSS', 'TAXES', 'NET']) {
    assert.ok(report.includes(column), `missing header ${column}`);
  }
  assert.match(report, /PAGE 0001 \| RUN \d{4}-\d{2}-\d{2}/);
  assert.match(report, /100101\s+Morgan\s+Alex\s+ENG\s+40\.00\s+5\.00/);
  assert.match(report, /DEPARTMENT ENG\s+\| EMPLOYEES 000002 \| GROSS \$3,468.75 \| TAXES \$1,081.93 \| NET \$2,386.82/);
  assert.equal((report.match(/DEPARTMENT ENG/g) ?? []).length, 1, 'noncontiguous ENG records grouped once');
  assert.match(report, /GRAND TOTAL \| EMPLOYEES 000003 \| GROSS \$4,518.75 \| TAXES \$1,385.76 \| NET \$3,132.99/);
  assert.match(report, /BALANCED \| DEBITS \$4,518.75 = CREDITS \$4,518.75/);
  const machineResult = readFileSync(outputPath(directory, 'results.psv'), 'utf8');
  assert.equal(machineResult.trim().split(/\r?\n/).length, 4);
  const nextMaster = readFileSync(outputPath(directory, 'emp_master_new.dat'));
  assert.match(run('payrollobol', directory, false), /already be posted/);
  assert.equal(readLedger(directory).length, 15);
  assert.deepEqual(readFileSync(outputPath(directory, 'emp_master_new.dat')), nextMaster);
  assert.equal(readFileSync(outputPath(directory, 'payroll_report.txt'), 'utf8'), report);
});

test('time-card EOF preserves employees with no card', () => {
  const directory = fixture();
  const original = readFileSync(inputPath(directory, 'emp_master'));
  writeFileSync(inputPath(directory, 'timecards'), readFileSync(inputPath(directory, 'timecards')).subarray(32, 64));
  run('payrollobol', directory);
  const updated = readFileSync(outputPath(directory, 'emp_master_new.dat'));
  assert.equal(updated.length, 300);
  assert.deepEqual(updated.subarray(0, 100), original.subarray(0, 100));
  assert.deepEqual(updated.subarray(200), original.subarray(200));
  assert.equal(readLedger(directory).length, 5);
});

rejection('unmatched leading card', directory => {
  const cards = readFileSync(inputPath(directory, 'timecards')); cards.write('100099', 0);
  writeFileSync(inputPath(directory, 'timecards'), cards);
}, /Unmatched time card/);
rejection('unmatched trailing card after master EOF rolls back prior postings', directory => {
  const cards = readFileSync(inputPath(directory, 'timecards')); cards.write('999999', 64);
  writeFileSync(inputPath(directory, 'timecards'), cards);
}, /Unmatched time card after employee EOF/);
rejection('empty employee file', directory => writeFileSync(inputPath(directory, 'emp_master'), ''), /Unmatched/);
rejection('empty time-card file', directory => writeFileSync(inputPath(directory, 'timecards'), ''), /No time cards/);
rejection('truncated employee', directory => {
  writeFileSync(inputPath(directory, 'emp_master'), readFileSync(inputPath(directory, 'emp_master')).subarray(0, 299));
}, /Malformed/);
rejection('truncated time card', directory => {
  writeFileSync(inputPath(directory, 'timecards'), readFileSync(inputPath(directory, 'timecards')).subarray(0, 95));
}, /Malformed/);
rejection('invalid packed decimal', directory => {
  const master = readFileSync(inputPath(directory, 'emp_master')); master[41] = 0xff;
  writeFileSync(inputPath(directory, 'emp_master'), master);
}, /packed-decimal/);
rejection('duplicate employee keys', directory => {
  const master = readFileSync(inputPath(directory, 'emp_master')); master.write('100101', 100);
  writeFileSync(inputPath(directory, 'emp_master'), master);
}, /Employee keys/);
rejection('duplicate time-card keys', directory => {
  const cards = readFileSync(inputPath(directory, 'timecards')); cards.write('100101', 32);
  writeFileSync(inputPath(directory, 'timecards'), cards);
}, /Time-card keys/);
rejection('unsorted time-card keys', directory => {
  const cards = readFileSync(inputPath(directory, 'timecards'));
  writeFileSync(inputPath(directory, 'timecards'), Buffer.concat([cards.subarray(32, 64), cards.subarray(0, 32)]));
}, /Time-card keys/);
rejection('mixed pay periods', directory => {
  const cards = readFileSync(inputPath(directory, 'timecards')); cards.write('20260930', 46);
  writeFileSync(inputPath(directory, 'timecards'), cards);
}, /Mixed pay periods/);
rejection('invalid calendar date', directory => {
  const cards = readFileSync(inputPath(directory, 'timecards')); cards.write('20260230', 14);
  writeFileSync(inputPath(directory, 'timecards'), cards);
}, /Invalid pay-period date/);
rejection('non-numeric hours', directory => {
  const cards = readFileSync(inputPath(directory, 'timecards')); cards.write('XXXX', 6);
  writeFileSync(inputPath(directory, 'timecards'), cards);
}, /Non-numeric/);
rejection('YTD overflow rolls back database', directory => {
  const master = readFileSync(inputPath(directory, 'emp_master'));
  Buffer.from('999999999f', 'hex').copy(master, 44);
  writeFileSync(inputPath(directory, 'emp_master'), master);
}, /overflow/);
test('recovery marker blocks new runs without deleting evidence', () => {
  const directory = fixture();
  writeFileSync(outputPath(directory, 'publication.pending'), 'recovery evidence');
  assert.match(run('payrollobol', directory, false), /recovery required/);
  assert.equal(readFileSync(outputPath(directory, 'publication.pending'), 'utf8'), 'recovery evidence');
  assert.equal(readLedger(directory).length, 0);
});
test('report pagination repeats headers and consolidates interleaved departments', () => {
  const directory = fixture();
  const seedMaster = readFileSync(inputPath(directory, 'emp_master')).subarray(0, 100);
  const seedCard = readFileSync(inputPath(directory, 'timecards')).subarray(0, 32);
  const masters = []; const cards = [];
  for (let index = 0; index < 60; index++) {
    const master = Buffer.from(seedMaster); const card = Buffer.from(seedCard);
    const id = String(200000 + index);
    master.write(id, 0); card.write(id, 0); master.write(index % 2 ? 'OPS ' : 'ENG ', 36);
    masters.push(master); cards.push(card);
  }
  writeFileSync(inputPath(directory, 'emp_master'), Buffer.concat(masters));
  writeFileSync(inputPath(directory, 'timecards'), Buffer.concat(cards));
  run('payrollobol', directory);
  const report = readFileSync(outputPath(directory, 'payroll_report.txt'), 'utf8');
  const pages = report.split('\f');
  assert.equal(pages.length, 2);
  for (const page of pages) assert.match(page, /EMP ID.*NAME.*DEPT/);
  assert.match(report, /PAGE 0002/);
  assert.equal((report.match(/DEPARTMENT /g) ?? []).length, 2);
  assert.match(report, /EMPLOYEES 000060/);
  assert.match(report, /BALANCED/);
  assert.equal(readLedger(directory).length, 300);
});

console.log(`\nBackend integration: ${checks} passed, ${failures} failed. Fixtures: ${work}`);
process.exitCode = failures ? 1 : 0;
