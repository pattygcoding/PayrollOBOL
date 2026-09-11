<script lang="ts">
  import { onMount } from "svelte";
  import {
    ArrowDownToLine,
    ArrowRight,
    ArrowUpRight,
    Building2,
    CalendarDays,
    Check,
    CheckCheck,
    ChevronRight,
    CircleAlert,
    CircleCheck,
    Database,
    FileText,
    Layers3,
    ListChecks,
    LoaderCircle,
    Play,
    RefreshCw,
    Scale,
    Search,
    Users,
    Wallet,
    X,
  } from "@lucide/svelte";
  import { payrollAdapter } from "./lib/adapter";
  import {
    accounts,
    type AccountCode,
    type DataSource,
    type EmployeeResult,
    type PayrollSnapshot,
  } from "./lib/models";
  import {
    balance,
    cents,
    decimal,
    departments,
    money,
    periodLabel,
    share,
    summarize,
    taxes,
  } from "./lib/money";

  type View = "register" | "departments" | "ledger" | "report";
  const navigation = [
    { id: "register" as View, label: "Payroll register", icon: ListChecks },
    { id: "departments" as View, label: "Departments", icon: Building2 },
    { id: "ledger" as View, label: "General ledger", icon: Scale },
    { id: "report" as View, label: "Print report", icon: FileText },
  ];
  let view = $state<View>("register");
  let source = $state<DataSource>("local");
  let snapshot = $state<PayrollSnapshot | null>(null);
  let phase = $state<"loading" | "idle" | "running" | "error" | "success">(
    "loading",
  );
  let message = $state("");
  let query = $state("");
  let department = $state("all");
  let sort = $state("id");
  let confirmation: HTMLDialogElement;
  let employeeDialog: HTMLDialogElement;
  let selected = $state<EmployeeResult | null>(null);
  const busy = $derived(phase === "loading" || phase === "running");
  const employees = $derived(snapshot?.employees ?? []);
  const totals = $derived(summarize(employees));
  const groups = $derived(departments(employees));
  const ledgerBalance = $derived(balance(snapshot));
  const visible = $derived(
    employees
      .filter(
        (employee) =>
          (department === "all" || employee.department === department) &&
          `${employee.id} ${employee.firstName} ${employee.lastName}`
            .toLowerCase()
            .includes(query.toLowerCase()),
      )
      .toSorted((left, right) =>
        sort === "name"
          ? left.lastName.localeCompare(right.lastName)
          : sort === "net"
            ? cents(left.net) === cents(right.net)
              ? 0
              : cents(left.net) > cents(right.net)
                ? -1
                : 1
            : left.id.localeCompare(right.id),
      ),
  );
  const displayedTotals = $derived(summarize(visible));
  const accountTotals = $derived(
    (Object.keys(accounts) as AccountCode[]).map((account) => ({
      account,
      name: accounts[account],
      debit:
        snapshot?.ledger
          .filter((entry) => entry.account === account)
          .reduce((sum, entry) => sum + cents(entry.debit), 0n) ?? 0n,
      credit:
        snapshot?.ledger
          .filter((entry) => entry.account === account)
          .reduce((sum, entry) => sum + cents(entry.credit), 0n) ?? 0n,
    })),
  );

  async function load(nextSource = source) {
    phase = "loading";
    message = "";
    source = nextSource;
    snapshot = null;
    query = "";
    department = "all";
    try {
      snapshot = await payrollAdapter.load(nextSource);
      phase = "idle";
    } catch (error) {
      phase = "error";
      message =
        error instanceof Error ? error.message : "Could not load payroll.";
    }
  }
  async function run() {
    confirmation.close();
    phase = "running";
    message = "";
    try {
      snapshot = await payrollAdapter.run(source);
      phase = "success";
      message =
        source === "demo"
          ? "Demo run complete. No ledger entries were posted."
          : "Payroll posted successfully. Ledger balanced and next master generated.";
    } catch (error) {
      phase = "error";
      message = error instanceof Error ? error.message : "Payroll failed.";
    }
  }
  function inspect(employee: EmployeeResult) {
    selected = employee;
    employeeDialog.showModal();
  }
  function downloadReport() {
    if (!snapshot?.report) return;
    const url = URL.createObjectURL(
      new Blob([snapshot.report], { type: "text/plain;charset=utf-8" }),
    );
    const link = document.createElement("a");
    link.href = url;
    link.download = `${source === "demo" ? "demo_" : ""}payroll_report_${snapshot.period}.txt`;
    link.click();
    URL.revokeObjectURL(url);
  }
  onMount(() => {
    void load();
  });
</script>

<svelte:head
  ><title>PayrollOBOL | Payroll Workspace</title><meta
    name="description"
    content="Local payroll register, department totals, and general ledger."
  /></svelte:head
>

<div class="app-shell">
  <aside class="sidebar">
    <a
      class="brand"
      href="#payroll"
      onclick={() => (view = "register")}
      aria-label="PayrollOBOL home"
      ><img src="/brand.png" width="34" height="34" alt="" /><span
        >Payroll<span class="brand-light">OBOL</span></span
      ></a
    >
    <div class="workspace-name">
      <span class="workspace-icon"><Building2 size={16} /></span>
      <div>Payroll workspace<small>Local operations</small></div>
    </div>
    <p class="nav-label">WORKSPACE</p>
    <nav aria-label="Workspace navigation">
      {#each navigation as item}<button
          class:active={view === item.id}
          onclick={() => (view = item.id)}
          aria-current={view === item.id ? "page" : undefined}
          aria-label={item.label}
          title={item.label}
          ><item.icon size={18} /><span>{item.label}</span
          >{#if view === item.id}<span class="nav-dot"></span>{/if}</button
        >{/each}
    </nav>
    <div class="sidebar-bottom">
      <div><span class="status-dot"></span> Local environment</div>
      <p>GnuCOBOL <span>3.2+</span></p>
      <p>Ledger <span>SQLite 3</span></p>
      <div class="version">PAYROLLOBOL / 1.0</div>
    </div>
  </aside>
  <div class="main-shell">
    <header class="topbar">
      <div class="breadcrumb">
        Workspace <ChevronRight size={13} /><span>Payroll</span>
      </div>
      <div class="topbar-right">
        <span class="private-label"><Database size={14} /> On this device</span
        ><span class="operator-avatar" title="Local operator">LO</span>
      </div>
    </header>
    <main>
      <div class="page-heading">
        <div>
          <div class="eyebrow">PAYROLL OPERATIONS</div>
          <h1>Payroll workspace</h1>
          <p>
            Pay period ending <strong
              >{periodLabel(
                snapshot?.period ?? snapshot?.inputPeriod ?? null,
              )}</strong
            >
          </p>
        </div>
        <div class="heading-actions">
          <button
            class="icon-button"
            title="Refresh payroll data"
            aria-label="Refresh payroll data"
            disabled={busy}
            onclick={() => load()}
            ><RefreshCw
              size={17}
              class={phase === "loading" ? "spinning" : ""}
            /></button
          ><button
            class="button secondary"
            disabled={!snapshot?.report || busy}
            onclick={downloadReport}
            ><ArrowDownToLine size={16} /> Export report</button
          ><button
            class="button primary"
            disabled={busy ||
              !snapshot?.canRun ||
              snapshot.source !== source ||
              phase === "error"}
            onclick={() => confirmation.showModal()}
            >{#if phase === "running"}<LoaderCircle
                size={17}
                class="spinning"
              /> Processing{:else}<Play
                size={15}
                fill="currentColor"
              />{source === "demo" ? "Run demo" : "Run Payroll"}{/if}</button
          >
        </div>
      </div>
      <div class="batch-strip">
        <div class="batch-identity">
          <CalendarDays size={18} /><span
            >PERIOD <strong
              >{snapshot?.inputPeriod ?? snapshot?.period ?? "--------"}</strong
            ></span
          ><span class:ready={snapshot?.status === "ready"} class="status-pill"
            >{busy
              ? phase === "running"
                ? "Processing"
                : "Loading"
              : snapshot?.status === "posted"
                ? "Posted"
                : snapshot?.status === "ready"
                  ? "Ready to run"
                  : "Awaiting input"}</span
          >
        </div>
        <fieldset class="source-switch" disabled={busy}>
          <legend class="sr-only">Data source</legend><label
            class:chosen={source === "local"}
            ><input
              type="radio"
              name="source"
              value="local"
              checked={source === "local"}
              onchange={() => load("local")}
            />Local batch</label
          ><label class:chosen={source === "demo"}
            ><input
              type="radio"
              name="source"
              value="demo"
              checked={source === "demo"}
              onchange={() => load("demo")}
            />Demo data</label
          >
        </fieldset>
      </div>
      <div class="batch-note">
        <span
          >{snapshot?.reason ?? "Connecting to local payroll adapter..."}</span
        >{#if snapshot?.generatedAt}<span
            >Updated {new Date(snapshot.generatedAt).toLocaleString("en-US", {
              month: "short",
              day: "numeric",
              hour: "numeric",
              minute: "2-digit",
            })}</span
          >{/if}
      </div>
      {#if phase === "error"}<div class="notice error" role="alert">
          <CircleAlert size={20} />
          <div>
            <strong>Payroll needs attention</strong>
            <p>{message}</p>
          </div>
          <button
            class="button secondary"
            onclick={() => load()}
            disabled={busy}>Retry</button
          >
        </div>{/if}
      {#if phase === "success"}<div class="notice success" role="status">
          <CircleCheck size={19} />
          <p>{message}</p>
          <button
            class="icon-button"
            title="Dismiss notification"
            aria-label="Dismiss notification"
            onclick={() => (phase = "idle")}><X size={16} /></button
          >
        </div>{/if}
      {#if busy}<div class="loading-line" role="status">
          <LoaderCircle size={16} class="spinning" />{phase === "running"
            ? "Processing payroll and posting ledger entries..."
            : "Loading payroll data..."}
        </div>{/if}
      <section class="metrics" aria-label="Payroll summary" aria-busy={busy}>
        <div class="metric">
          <div class="metric-label">
            Employees processed <Users size={16} />
          </div>
          <strong>{totals.count.toString().padStart(2, "0")}</strong><span
            >{groups.length} departments</span
          >
        </div>
        <div class="metric">
          <div class="metric-label">Gross payroll <Wallet size={16} /></div>
          <strong>{money(totals.gross)}</strong><span
            >{decimal(totals.regular + totals.overtime)} total hours</span
          >
        </div>
        <div class="metric">
          <div class="metric-label">Taxes withheld <Layers3 size={16} /></div>
          <strong>{money(totals.tax)}</strong><span
            >Federal, state &amp; FICA</span
          >
        </div>
        <div class="metric net-metric">
          <div class="metric-label">
            Net disbursement <ArrowUpRight size={17} />
          </div>
          <strong>{money(totals.net)}</strong><span>Cash clearing / 1001</span>
        </div>
      </section>
      <div class="section-tabs" role="tablist" aria-label="Payroll views">
        {#each navigation as item}<button
            role="tab"
            aria-selected={view === item.id}
            class:current={view === item.id}
            onclick={() => (view = item.id)}
            >{item.label}{#if item.id === "register"}<span class="tab-count"
                >{totals.count}</span
              >{/if}</button
          >{/each}
      </div>
      {#if employees.length === 0 && !busy}
        <section class="empty-state">
          <ListChecks size={32} />
          <h2>No payroll results yet</h2>
          <p>{snapshot?.reason ?? "Local payroll data is unavailable."}</p>
          {#if snapshot?.canRun}<button
              class="button primary"
              onclick={() => confirmation.showModal()}
              ><Play size={15} /> Run Payroll</button
            >{:else}<button
              class="button secondary"
              onclick={() => load("demo")}
              >Open demo dataset <ArrowRight size={15} /></button
            >{/if}
        </section>
      {:else if view === "register"}
        <section class="register-section" aria-label="Employee results">
          <div class="section-toolbar">
            <div>
              <h2>Employee register</h2>
              <span class="muted"
                >{visible.length} of {employees.length} employees</span
              >
            </div>
            <div class="filters">
              <label class="search-box"
                ><Search size={16} /><input
                  aria-label="Search employees"
                  placeholder="Search name or ID..."
                  bind:value={query}
                />{#if query}<button
                    class="clear-search"
                    aria-label="Clear search"
                    title="Clear search"
                    onclick={() => (query = "")}><X size={14} /></button
                  >{/if}</label
              ><select aria-label="Filter by department" bind:value={department}
                ><option value="all">All departments</option
                >{#each groups as group}<option value={group.name}
                    >{group.name}</option
                  >{/each}</select
              ><select aria-label="Sort employees" bind:value={sort}
                ><option value="id">Employee ID</option><option value="name"
                  >Last name</option
                ><option value="net">Highest net pay</option></select
              >
            </div>
          </div>
          <div
            class="table-scroll"
            role="region"
            aria-label="Employee payroll table"
          >
            <table class="employee-table">
              <thead
                ><tr
                  ><th>Employee</th><th>Employee ID</th><th>Dept.</th><th
                    class="numeric">Reg. hrs</th
                  ><th class="numeric">OT hrs</th><th class="numeric"
                    >Gross pay</th
                  ><th class="numeric">Taxes</th><th class="numeric">Net pay</th
                  ><th><span class="sr-only">Details</span></th></tr
                ></thead
              ><tbody
                >{#each visible as employee}<tr
                    ><td
                      ><div class="employee-cell">
                        <span
                          class="employee-avatar"
                          class:ops={employee.department === "OPS"}
                          >{employee.firstName[0]}{employee.lastName[0]}</span
                        ><strong
                          >{employee.firstName} {employee.lastName}</strong
                        >
                      </div></td
                    ><td class="mono muted">{employee.id}</td><td
                      ><span
                        class="department-tag"
                        class:ops={employee.department === "OPS"}
                        >{employee.department}</span
                      ></td
                    ><td class="numeric muted"
                      >{decimal(cents(employee.regularHours))}</td
                    ><td
                      class="numeric"
                      class:muted={cents(employee.overtimeHours) === 0n}
                      >{decimal(cents(employee.overtimeHours))}</td
                    ><td class="numeric">{money(employee.gross)}</td><td
                      class="numeric muted">{money(taxes(employee))}</td
                    ><td class="numeric net-value">{money(employee.net)}</td><td
                      ><button
                        class="row-button"
                        title={`View ${employee.firstName}'s pay breakdown`}
                        aria-label={`View ${employee.firstName} ${employee.lastName} details`}
                        onclick={() => inspect(employee)}
                        ><ChevronRight size={17} /></button
                      ></td
                    ></tr
                  >{/each}</tbody
              ><tfoot
                ><tr
                  ><td colspan="3"
                    >{query || department !== "all"
                      ? "Filtered total"
                      : "Payroll total"}<span class="total-count"
                      >{visible.length} employees</span
                    ></td
                  ><td class="numeric">{decimal(displayedTotals.regular)}</td
                  ><td class="numeric">{decimal(displayedTotals.overtime)}</td
                  ><td class="numeric">{money(displayedTotals.gross)}</td><td
                    class="numeric">{money(displayedTotals.tax)}</td
                  ><td class="numeric net-value"
                    >{money(displayedTotals.net)}</td
                  ><td></td></tr
                ></tfoot
              >
            </table>
          </div>
          {#if visible.length === 0}<div class="no-match">
              <Search size={22} />
              <h3>No matching employees</h3>
              <button
                class="text-button"
                onclick={() => {
                  query = "";
                  department = "all";
                }}>Clear filters</button
              >
            </div>{/if}
          <div class="register-footnote">
            <CheckCheck size={15} />{source === "demo"
              ? "Seeded demonstration results"
              : "Published batch results"}<span>USD</span>
          </div>
        </section>
      {:else if view === "departments"}
        <section class="department-section">
          <div class="section-toolbar">
            <div>
              <h2>Department totals</h2>
              <span class="muted"
                >{groups.length} departments / {totals.count} employees</span
              >
            </div>
          </div>
          <div
            class="table-scroll"
            role="region"
            aria-label="Department subtotal table"
          >
            <table>
              <thead
                ><tr
                  ><th>Department</th><th class="numeric">Employees</th><th
                    class="numeric">Regular hours</th
                  ><th class="numeric">Overtime</th><th class="numeric"
                    >Gross</th
                  ><th class="numeric">Taxes</th><th class="numeric">Net</th
                  ></tr
                ></thead
              ><tbody
                >{#each groups as group}<tr
                    ><td
                      ><span
                        class="department-tag"
                        class:ops={group.name === "OPS"}>{group.name}</span
                      ></td
                    ><td class="numeric">{group.count}</td><td class="numeric"
                      >{decimal(group.regular)}</td
                    ><td class="numeric">{decimal(group.overtime)}</td><td
                      class="numeric">{money(group.gross)}</td
                    ><td class="numeric muted">{money(group.tax)}</td><td
                      class="numeric net-value">{money(group.net)}</td
                    ></tr
                  >{/each}</tbody
              >
            </table>
          </div>
        </section>
      {:else if view === "ledger"}
        <section class="ledger-section">
          <div class="section-toolbar">
            <div>
              <h2>General ledger</h2>
              <span class="muted"
                >{snapshot?.ledger.length ?? 0} entries / {periodLabel(
                  snapshot?.period ?? null,
                )}</span
              >
            </div>
            <span
              class="balance-label"
              class:unbalanced={!ledgerBalance.balanced}
              ><Scale size={16} />{ledgerBalance.balanced
                ? "Balanced"
                : "Out of balance"}</span
            >
          </div>
          <div
            class="table-scroll"
            role="region"
            aria-label="General ledger account totals"
          >
            <table>
              <thead
                ><tr
                  ><th>Account</th><th>Account name</th><th class="numeric"
                    >Debit</th
                  ><th class="numeric">Credit</th></tr
                ></thead
              ><tbody
                >{#each accountTotals as account}<tr
                    ><td class="mono">{account.account}</td><td
                      >{account.name}</td
                    ><td class="numeric">{money(account.debit)}</td><td
                      class="numeric">{money(account.credit)}</td
                    ></tr
                  >{/each}</tbody
              ><tfoot
                ><tr
                  ><td colspan="2">Ledger total</td><td class="numeric"
                    >{money(ledgerBalance.debit)}</td
                  ><td class="numeric">{money(ledgerBalance.credit)}</td></tr
                ></tfoot
              >
            </table>
          </div>
          <details class="ledger-details">
            <summary
              >Individual ledger entries <span>{snapshot?.ledger.length}</span
              ></summary
            >
            <div
              class="table-scroll"
              role="region"
              aria-label="Individual ledger entries"
            >
              <table>
                <thead
                  ><tr
                    ><th>Employee ID</th><th>Account</th><th class="numeric"
                      >Debit</th
                    ><th class="numeric">Credit</th></tr
                  ></thead
                ><tbody
                  >{#each snapshot?.ledger ?? [] as entry}<tr
                      ><td class="mono">{entry.employeeId}</td><td
                        >{entry.account} / {accounts[entry.account]}</td
                      ><td class="numeric">{money(entry.debit)}</td><td
                        class="numeric">{money(entry.credit)}</td
                      ></tr
                    >{/each}</tbody
                >
              </table>
            </div>
          </details>
        </section>
      {:else}
        <section class="report-section">
          <div class="section-toolbar">
            <div>
              <h2>Payroll print report</h2>
              <span class="muted"
                >{source === "demo"
                  ? "Demonstration register"
                  : "payroll_report.txt"}</span
              >
            </div>
            <button
              class="icon-button"
              title="Download print report"
              aria-label="Download print report"
              onclick={downloadReport}><ArrowDownToLine size={18} /></button
            >
          </div>
          <div
            class="report-preview"
            role="region"
            aria-label="Payroll report preview"
          >
            <pre>{snapshot?.report || "No report available."}</pre>
          </div>
        </section>
      {/if}
      {#if employees.length > 0}<div class="insights">
          <section class="allocation">
            <div class="small-section-heading">
              <h2>Payroll by department</h2>
              <button
                class="icon-button"
                title="View department totals"
                aria-label="View department totals"
                onclick={() => (view = "departments")}
                ><ArrowUpRight size={17} /></button
              >
            </div>
            <div
              class="allocation-bar"
              aria-label="Department gross payroll allocation"
            >
              {#each groups as group, index}<div
                  class:alternate={index % 2 === 1}
                  style:width={`${share(group.gross, totals.gross)}%`}
                  title={`${group.name}: ${money(group.gross)}`}
                ></div>{/each}
            </div>
            <div class="allocation-legend">
              {#each groups as group, index}<div>
                  <span class="legend-swatch" class:alternate={index % 2 === 1}
                  ></span><span
                    >{group.name}<small>{group.count} employees</small></span
                  ><strong>{money(group.gross)}</strong>
                </div>{/each}
            </div>
          </section>
          <section class="reconciliation">
            <div class="small-section-heading">
              <h2>Ledger reconciliation</h2>
              <span
                class="balance-label"
                class:unbalanced={!ledgerBalance.balanced}
                ><Check size={14} />{ledgerBalance.balanced
                  ? "Balanced"
                  : "Mismatch"}</span
              >
            </div>
            <div class="balance-amounts">
              <div>
                <span>Total debits</span><strong
                  >{money(ledgerBalance.debit)}</strong
                >
              </div>
              <Scale size={23} />
              <div>
                <span>Total credits</span><strong
                  >{money(ledgerBalance.credit)}</strong
                >
              </div>
            </div>
            <div class="balance-bottom">
              <span>{snapshot?.ledger.length} entries across 5 accounts</span
              ><strong>Difference {money(ledgerBalance.difference)}</strong>
            </div>
          </section>
        </div>{/if}
      <footer class="page-footer">
        <span
          ><span class="status-dot"></span>{source === "demo"
            ? "Demo dataset"
            : "Local payroll ledger"}</span
        ><span>PAYROLLOBOL <span class="footer-slash">/</span> USD</span>
      </footer>
    </main>
  </div>
</div>
<dialog bind:this={confirmation} aria-labelledby="confirm-title">
  <div class="dialog-top">
    <span class="dialog-icon"><Play size={20} /></span>
    <form method="dialog">
      <button class="icon-button" aria-label="Close confirmation" title="Close"
        ><X size={19} /></button
      >
    </form>
  </div>
  <h2 id="confirm-title">
    {source === "demo" ? "Run the demo batch?" : "Post this payroll?"}
  </h2>
  <p>Pay period ending {periodLabel(snapshot?.inputPeriod ?? null)}</p>
  <div class="confirmation-note">
    {source === "demo"
      ? "This uses seeded results. No files or ledger entries will be changed."
      : "This posts the input batch to the local ledger and creates the next employee master. A posted period cannot be run twice."}
  </div>
  <div class="dialog-actions">
    <form method="dialog">
      <button class="button secondary">Cancel</button>
    </form>
    <button class="button primary" onclick={run}
      ><Play size={14} />{source === "demo"
        ? "Run demo"
        : "Confirm payroll"}</button
    >
  </div>
</dialog>
<dialog
  bind:this={employeeDialog}
  class="employee-dialog"
  aria-labelledby="employee-title"
>
  <div class="dialog-top">
    <span class="eyebrow">EMPLOYEE {selected?.id}</span>
    <form method="dialog">
      <button
        class="icon-button"
        aria-label="Close employee details"
        title="Close"><X size={19} /></button
      >
    </form>
  </div>
  {#if selected}<h2 id="employee-title">
      {selected.firstName}
      {selected.lastName}
    </h2>
    <p>{selected.department} / {periodLabel(selected.period)}</p>
    <dl class="pay-breakdown">
      <div>
        <dt>
          Regular pay <small
            >{decimal(cents(selected.regularHours))} hours</small
          >
        </dt>
        <dd>{money(selected.regularPay)}</dd>
      </div>
      <div>
        <dt>
          Overtime pay <small
            >{decimal(cents(selected.overtimeHours))} hours</small
          >
        </dt>
        <dd>{money(selected.overtimePay)}</dd>
      </div>
      <div class="breakdown-total">
        <dt>Gross pay</dt>
        <dd>{money(selected.gross)}</dd>
      </div>
      <div>
        <dt>Federal withholding</dt>
        <dd>{money(selected.federal)}</dd>
      </div>
      <div>
        <dt>State withholding</dt>
        <dd>{money(selected.state)}</dd>
      </div>
      <div>
        <dt>FICA</dt>
        <dd>{money(selected.fica)}</dd>
      </div>
      <div class="breakdown-net">
        <dt>Net pay</dt>
        <dd>{money(selected.net)}</dd>
      </div>
    </dl>{/if}
</dialog>
