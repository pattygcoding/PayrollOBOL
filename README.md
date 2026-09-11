<div align="left">
	<h1>PayrollOBOL</h1>
	<p><strong>COBOL payroll processing with a SQLite ledger and a Svelte operations dashboard.</strong></p>
	<p>
		<img alt="GnuCOBOL" src="https://img.shields.io/badge/GnuCOBOL-3.2%2B-244b5a?style=flat-square">
		<img alt="SQLite" src="https://img.shields.io/badge/SQLite-ledger-0f80cc?style=flat-square">
		<img alt="Svelte" src="https://img.shields.io/badge/Svelte-5-ff3e00?style=flat-square">
		<img alt="Windows" src="https://img.shields.io/badge/Windows-local--first-0078d4?style=flat-square">
	</p>
	<p><code>batch payroll</code> <code>double-entry ledger</code> <code>integer-cent math</code> <code>loopback dashboard</code></p>
</div>

<hr>

Local GnuCOBOL payroll, a SQLite double-entry ledger, and a Svelte dashboard. The implementation is in [payrollobol/](payrollobol/README.md).

## Quick Start (Windows)

Requires **64-bit GnuCOBOL 3.2+, matching MinGW GCC/SQLite libraries**, and **Node.js 22.13+ or 24 LTS**. See the [toolchain guide](payrollobol/README.md#toolchain).

From PowerShell at the repository root:

```powershell
cd payrollobol
.\build.bat
.\seed.bat
.\run.bat
cd frontend
npm ci
npm run dev
```

Open **http://127.0.0.1:5173/**, or the alternate port printed by Vite. To try Run Payroll in the dashboard, omit `run.bat` above. **Demo data** mode never posts ledger entries. The seeder refuses to overwrite inputs, and posted periods cannot be posted again.

## Verification

```powershell
cd payrollobol
.\tests\build-tests.bat
cd frontend
npm ci
npm test
npx playwright install chromium
npm run test:e2e
npm run build
```

The normal COBOL build includes the backend test gate. Tests use isolated fixtures, not normal payroll files. The frontend production build includes Svelte/TypeScript checks.

The seeded batch processes three employees: **gross $4,518.75**, **taxes $1,385.76**, **net $3,132.99**, with 15 balanced ledger entries.

## Operational Notes

- The supplied copybooks disagree with the specified physical record lengths. The implementation preserves the copybooks and explicitly maps them to 100-byte master / 32-byte card records. See the [binary contract](payrollobol/README.md#binary-format-contract).
- SQLite and flat-file publication are not one atomic transaction. A recovery marker blocks further work after an interruption; follow the [recovery procedure](payrollobol/README.md#interruption-recovery).
- These are the supplied simplified tax rules, not jurisdiction-compliant withholding. No wages are transferred or tax returns filed. Real production use requires payroll/legal review, access controls, backups, and operational acceptance testing.