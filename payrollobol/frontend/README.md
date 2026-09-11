# PayrollOBOL Dashboard

Svelte 5, TypeScript, Vite, and a loopback-only adapter for the native GnuCOBOL batch. Full installation and operator guidance is in [the project README](../README.md).

## Commands

Requires Node.js 22.13+ or 24 LTS. Run from this directory:

```powershell
npm ci
npm run dev
```

Open http://127.0.0.1:5173/ or the port printed by Vite. Build and seed the parent project for local operation. The explicit Demo data mode works without native binaries and does not write payroll files.

```powershell
npm run check
npm test
npx playwright install chromium
npm run test:e2e
npm run build
npm run preview
```

`build` checks types and produces `dist`. `preview` serves that build with the adapter on http://127.0.0.1:4173/. Static-only hosting does not provide local API access. Do not expose the development or preview server publicly.

Unit/bridge tests require compiled native binaries in `../bin`. Browser tests run a separate server on port 5180 with isolated fixtures; screenshots and failure traces are in `test-results`. Normal input/output data is not modified by tests.

## Code Map

- `src/lib/models.ts`: Zod-validated decimal-string models and calendar dates.
- `src/lib/money.ts`: BigInt cent formatting, grouping, and reconciliation; no floating-point payroll calculation.
- `src/lib/demo.ts`: deterministic seed-equivalent display data.
- `src/lib/adapter.ts`: explicit local/demo boundary.
- `server/bridge.ts`: read-only result/ledger inspection and guarded native process execution.
- `src/App.svelte`: batch controls, register, employee details, departments, ledger, and report.
- `src/app.css`: responsive layout and locally bundled fonts.

The local ledger-book bitmap can be regenerated on Windows with `scripts/generate-brand.ps1`. Icons use `@lucide/svelte`.