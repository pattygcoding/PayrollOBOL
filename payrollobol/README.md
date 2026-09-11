# PayrollOBOL

A modular Windows batch payroll engine, SQLite ledger, and local Svelte dashboard. Payroll arithmetic belongs to COBOL; the browser only formats decimal strings and aggregates integer cents.

## Toolchain

Use matching **x86-64** builds of GnuCOBOL 3.2+, MinGW GCC, SQLite, and the COBOL runtime dependencies. Do not combine a 32-bit Chocolatey compiler with 64-bit SQLite. Install Node.js **22.13+** or **24 LTS** and npm. Node 22 may print an informational experimental warning for its built-in SQLite module.

One installation option is MSYS2's MINGW64 environment. From that environment:

```sh
pacman -S --needed mingw-w64-x86_64-gnucobol mingw-w64-x86_64-sqlite3 mingw-w64-x86_64-gcc
```

Then configure the same installation in Windows Command Prompt:

```bat
set "MINGW_HOME=C:\msys64\mingw64"
set "PATH=%MINGW_HOME%\bin;%PATH%"
set "COB_CONFIG_DIR=%MINGW_HOME%\share\gnucobol\config"
set "COB_COPY_DIR=%MINGW_HOME%\share\gnucobol\copy"
set "COB_CFLAGS=-I "%MINGW_HOME%\include""
set "COB_LIBS=-L "%MINGW_HOME%\lib" -lcob"
cobc -V
gcc -dumpmachine
```

For PowerShell, set equivalent `$env:MINGW_HOME`, `$env:PATH`, and COB_* variables. Execute batch scripts with `.\`.

This workspace also has an ignored portable runtime under `.tools/mingw64`, provisioned during implementation. `env.bat` detects it and uses `C:\mingw64` for GCC/SQLite by default. **Those downloaded tools are not part of the repository.** A new clone needs its own toolchain. Set `MINGW_HOME` to override the GCC/SQLite location and `SQLITE_LIBS` for custom linker flags.

Sources use free-format modern COBOL, structured control flow, packed decimals, and GnuCOBOL C/file interfaces. Builds use the specified `-free`. Strict `-std=cobol2002` is not enabled: the supplied `COMP-3` / `COMP-5` spellings and runtime interfaces require the GnuCOBOL dialect. ISO-only cross-compiler portability is not claimed. `env.bat` adds `-std=gnu11` to generated C compilation because newer GCC's C23 prototype rules conflict with these generated static C calls.

## Build and Run

From this directory in PowerShell:

```powershell
.\build.bat
.\seed.bat
.\run.bat
```

`build.bat` creates directories, builds `bin/payrollobol.exe` and `bin/seed_data.exe`, then compiles/runs the backend tests. Failed compilation or assertions propagate a nonzero exit code. The seed/run wrappers establish DLL paths and the correct working directory. Direct binary execution also works after `call env.bat` in Command Prompt.

The seeder writes sorted data for **20260915**, with zero initial YTD balances. It fails if either input file already exists. It never resets the ledger or overwrites payroll data.

| Employee | Dept | Rate | Reg Hours | OT Hours | Gross | Federal | State | FICA | Net |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 100101 Alex Morgan | ENG | 32.50 | 40.00 | 5.00 | 1543.75 | 279.63 | 77.19 | 118.10 | 1068.83 |
| 100102 Jordan Chen | OPS | 28.00 | 37.50 | 0.00 | 1050.00 | 171.00 | 52.50 | 80.33 | 746.17 |
| 100103 Sam Patel | ENG | 35.00 | 40.00 | 10.00 | 1925.00 | 363.50 | 96.25 | 147.26 | 1317.99 |

Totals: **3 employees, gross 4518.75, taxes 1385.76, net 3132.99**. ENG gross is 3468.75; OPS gross is 1050.00. Ledger debits and credits both equal 4518.75.

### Outputs and Next Period

| Path | Purpose |
| --- | --- |
| `data/output/emp_master_new.dat` | Next master, including unchanged employees without cards |
| `data/output/payroll_report.txt` | Paginated department report and grand totals |
| `data/output/results.psv` | Dashboard export, decimal strings with two fractional digits |
| `data/payroll.db` | Persistent ledger and posted-period registry |

The current master is **never overwritten automatically**. Report/PSV describe the latest published batch; the ledger retains historical periods. Before the next period, archive current inputs/outputs and a consistent database backup. Reconcile all five YTD balances, then explicitly promote `emp_master_new.dat` to the next period's current master and provide new sorted cards. Never promote an unverified or recovery-pending generation. This version has no correction/reversal workflow, multiple batches per period, or automatic year-end reset.

## Dashboard

```powershell
cd frontend
npm ci
npm run dev
```

Open **http://127.0.0.1:5173/**. Vite prints another port if occupied. The dashboard has local/demo selection, run confirmation, processing/error/success/empty states, employee search/filter/sort and pay breakdown, department subtotals, ledger accounts/entries, reconciliation, and report preview/download. Demo mode uses the seed results without performing payroll arithmetic or writing files.

```powershell
npm run build
npm run preview
```

The checked production build is in `frontend/dist`; preview defaults to **http://127.0.0.1:4173/**. The adapter is installed in both Vite development and preview servers. A static-only server supports explicit demo mode but **not** local data/process execution. A missing bridge produces a visible error, not silently substituted demo data.

`src/lib/adapter.ts` is the UI boundary. `server/bridge.ts` parses PSV with `csv-parse`, validates models/calendar dates with Zod, reads SQLite read-only, and checks all five ledger amounts per employee before returning results. It never accepts arbitrary file paths. `PAYROLLOBOL_ROOT` can select another prepared payroll directory for testing.

The API provides `GET /api/payroll` and `POST /api/payroll/run`; execution requires `X-Payroll-Request: 1`. It accepts loopback clients with localhost/127.0.0.1 Host and matching Origin when present, has a single-run guard, and launches a fixed executable without a shell or user arguments.

Keep the server on loopback. This is a **trusted-local operator tool**, not an authenticated multiuser service. Loopback checks do not isolate other local programs/users. Restrict filesystem ACLs, secure the Windows account, and never expose Vite/API to a LAN or Internet. Protect files, backups, downloads, and screenshots as sensitive payroll data.

## Binary Format Contract

Both inputs are fixed `ORGANIZATION SEQUENTIAL`, **not LINE SEQUENTIAL**. No CR/LF separators, record-length prefixes, UTF-8 BOMs, or textual decimal points. Do not edit the master in a text editor; use the COBOL seeder or a compatible binary importer.

**Specification reconciliation:** the supplied employee copybook is **83 bytes**, not 100; the card copybook is **34 bytes**, not 32. All supplied copybook fields are preserved, with explicit physical mapping:

| Master Disk Bytes (1-Based) | Field |
| --- | --- |
| 1-6 | Six ASCII digits, employee ID |
| 7-21 / 22-36 | Last / first name, ASCII space-padded |
| 37-40 | Department, ASCII space-padded |
| 41-44 | Rate, unsigned `9(4)V99 COMP-3`, 4 bytes |
| 45-49 / 50-54 / 55-59 / 60-64 / 65-69 | YTD gross / federal / state / FICA / net, each `9(7)V99 COMP-3`, 5 bytes |
| 70-83 | Original copybook filler |
| 84-100 | Extra physical padding, preserved through the batch |

| Card Disk Bytes | Field |
| --- | --- |
| 1-6 | Employee ID |
| 7-10 / 11-14 | Regular / OT hours: four ASCII digits, implied two fractional digits |
| 15-22 | Period end `YYYYMMDD` |
| 23-32 | Ten spaces |

The card's meaningful 22 bytes are copied into the unchanged 34-byte copybook with its 12-byte internal filler initialized to spaces. `4000` means 40.00 hours. Seed files are exactly **300 bytes** of master and **96 bytes** of cards, with compiler-native valid packed decimals.

IDs must be nonzero and uniquely ascending. Every card must match a master; unmatched cards abort the entire batch, including cards after master EOF. Masters without cards are copied unchanged and excluded from payroll totals. A batch needs at least one card and one valid period. The driver rejects partial records, duplicate/unsorted IDs, nonnumeric hours/date fields, invalid packed decimals/calendar dates, nonspace card padding, empty departments, and nonprintable or pipe-containing names/departments.

## Calculation and Ledger Rules

`CALC-ENGINE` receives time card, employee master, and `CALC-RESULT` by reference. All money is packed decimal. Regular pay and 1.5x overtime are rounded independently to cents; gross is their sum. Federal tax is 10% of the first 500.00 plus 22% above 500.00; state is 5%; FICA is 7.65%. Each tax is rounded to cents before subtraction from gross. `ROUNDED` uses nearest-cent rounding, positive half cents up.

All five YTD fields use `ON SIZE ERROR`. Invalid data/overflow returns nonzero, restores the original employee, and clears the calculation result. No partial YTD changes are published. Calculation fields allow 999999.99; master YTD fields allow 9999999.99.

`DB-LOGGER` exposes `INIT-DB`, `LOG-TRANSACTION`, `COMMIT-DB`, and idempotent `CLOSE-DB`. Direct SQLite C calls use null-terminated SQL, check return codes, free error messages, start `BEGIN IMMEDIATE`, and roll back on uncommitted close. Busy timeout is 5 seconds. SQL values come from validated numeric fields/fixed accounts, never names.

Each employee generates gross debit **5001**, federal credit **2101**, state credit **2102**, FICA credit **2103**, and net credit **1001**. The supplied schema is preserved with an additive unique `(pay_period, emp_id, account_code)` index and `payroll_runs` period primary key to block replay.

**SQLite precision caveat:** `DECIMAL(10,2)` is numeric affinity, not fixed-point storage. Computation/SQL decimal literals are exact cents, but SQLite may store values as binary REAL. Do not use floating-point `SUM` equality for reconciliation. Adapter/tests read individual bounded amounts with `printf('%.2f', ...)`, convert to integer cents, and sum exactly. A future schema revision should use integer-cent columns if database-level exact arithmetic is required.

`REPORT-WRITER` supports `OPEN`, `DETAIL`, `FINISH`, and `ABORT`. Disk spooling and COBOL `SORT` by department/employee give correct subtotals even when departments are interleaved in the ID-sorted master. Pages repeat timestamp/column headers and include currency formatting, department/grand totals, and balance checks. Temporary spools are removed on normal completion/failure.

## Interruption Recovery

SQLite and three flat files are **not one atomic resource**. The batch writes `*.tmp` files and `data/output/publication.pending` while holding its transaction. It closes staged outputs, commits SQLite, publishes master/report/PSV, then removes the marker. Precommit failures roll back, remove owned staging files, and preserve prior published outputs. Postcommit failures retain the marker/remaining staging. Batch and dashboard refuse further work while the marker exists.

1. Stop all batch processes and the dashboard. Back up the entire payroll directory. Never delete the ledger or rerun a committed period.
2. Read the marker's period. Query `SELECT * FROM payroll_runs WHERE pay_period = 'YYYYMMDD';` in a SQLite client, substituting that period. Check ledger rows as well.
3. **No committed row:** retain current master/prior outputs, remove only this aborted run's staged `.tmp`/spool files and marker, correct the cause, and rerun.
4. **Committed row:** finish publication from remaining `emp_master_new.dat.tmp`, `payroll_report.txt.tmp`, and `results.psv.tmp` to their corresponding final names. A missing `.tmp` may mean the file was already renamed: verify final contents against the period/ledger/expected master. Never assume an older final file belongs to this run.
5. Reconcile all employees, five YTD fields, report totals, and ledger entries before removing the marker and leftover spools. If committed output is missing/unrecoverable, restore a consistent pre-run backup of database **and** files under a controlled procedure. Never blindly replay against partial recovery.

This detects ordinary interrupted publication, not guaranteed power-loss durability across filesystems. Test recovery with your storage, antivirus, backups, and permissions before real payroll. Do not replace inputs during an active batch.

## Tests

```powershell
.\tests\build-tests.bat
cd frontend
npm ci
npm test
npx playwright install chromium
npm run test:e2e
npm run build
```

Backend tests compile independently and use Node's built-in SQLite API, not frontend packages. `test_calc.cob` checks boundaries, OT, half-cent rounding, all YTD updates, overflow rollback, zero pay, and invalid data. `test_db.cob` checks commit/rollback/closure; `verify_master.cob` verifies generated packed-decimal YTDs. The integration harness runs **20** scenarios for matching/EOF, validation, rollback, replay, preserved outputs, control breaks/pagination, and seeded results.

Backend fixtures live under `tests/.work/run-*`. Bridge tests create/remove OS-temporary fixtures. Playwright starts its own server on port 5180 and uses isolated `tests/.work/browser-*` data, never normal payroll. Frontend tests cover BigInt totals, native execution, corruption, request restrictions, calendar dates, desktop/mobile filters/dialogs/download, and demo/loading/error/empty/success states. Screenshots go to `frontend/test-results`. Build native binaries before bridge/browser tests.

## Troubleshooting

- Missing `cobc`: install/expose the x64 toolchain. Scripts do not download compilers.
- Missing `/mingw/...` config: set the real COB_* paths shown above.
- SQLite link/format errors: `gcc -dumpmachine`, compiler, import library, DLL, and libcob must all match x86-64.
- Exit `0xC0000135` / `0xC0000139`: missing/mismatched DLLs. Use GnuCOBOL's dependency set from the same distribution, not random copied versions.
- Duplicate period: already committed. Review the ledger; never delete rows just to bypass the guard.
- Recovery required: follow the marker procedure, not another Run Payroll attempt.
- Dashboard error: inspect the message, build/seed the backend, and use Vite rather than static hosting. Demo is explicitly available for inspection.

The specified tax model is simplified. There are no statutory tables, benefits, garnishments, jurisdictional wage limits, tax filings, or bank transfers. This is not certified payroll software. Production adoption requires domain review, deployment security, audited operations, and acceptance testing.