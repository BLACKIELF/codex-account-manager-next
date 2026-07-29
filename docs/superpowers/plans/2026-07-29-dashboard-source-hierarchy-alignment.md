# Dashboard Source-Hierarchy Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the Windows Dashboard to the macOS source hierarchy: one lower content tab bar with Today tasks as default and AI Leadership as a drill-down tab.

**Architecture:** Keep `Dashboard.tsx` as the window shell, header, refresh/error boundary, and local-source status owner. Move the only Dashboard content-tab state into `DashboardHome`, which owns the macOS-equivalent overview plus `Tasks / AI Leadership / Usage / Projects / Skill` panels. `QuotaOverview` is a presentation-only consumer of the existing `UsageSnapshot`; it renders an explicit unavailable state whenever Windows cannot read official quota data.

**Tech Stack:** React 18, TypeScript 5, Vite, Tailwind utility classes, existing CSS custom-property design tokens, Tauri 2, Rust workspace tests, Node built-in test runner.

## Global Constraints

- macOS `Sources/CodexUsageWidget/main.swift` is the source of truth for Dashboard ordering and interaction hierarchy; the screenshot is only final visual evidence.
- Do not modify Rust readers, aggregation, cache, IPC, leadership scoring, quota contracts, task contracts, or enable Claude Code.
- Retain the existing `CodexDashboardSnapshot` / `UsageSnapshot` fields; do not fabricate quota, cost, task, or score data.
- A missing quota must state the returned source label, currently `Official quota unavailable on Windows`; it must not display `0%` as a quota value.
- A missing task board must remain distinct from `recent_threads`; do not relabel threads as tasks.
- Reuse the existing visual tokens and component patterns. Do not add hard-coded colors, emoji icons, or generated build artifacts.
- Build and Cargo commands run from `E:\project\codexU\windows`; web commands run from `E:\project\codexU\windows\apps\codexu-tauri\web`.
- Do not touch the existing untracked `docs/windows-port/reports/MAC_WINDOWS_ARCHITECTURE_ALIGNMENT_REVIEW.*` files.

---

## Planned File Structure

- Modify: `windows/apps/codexu-tauri/web/src/windows/Dashboard.tsx` — retain shell responsibilities and pass the existing runtime snapshot plus source labels into the unified Dashboard.
- Modify: `windows/apps/codexu-tauri/web/src/components/DashboardHome.tsx` — own one `DashboardContentTab` state, overview command entry, and all five lower panels.
- Create: `windows/apps/codexu-tauri/web/src/components/QuotaOverview.tsx` — render official quota/reset data when the current snapshot has it, otherwise an honest unavailable state.
- Modify: `windows/apps/codexu-tauri/web/src/index.css` — define source-order grid areas for compact and desktop overview layouts; remove orphaned home-level leadership-detail rules.
- Create: `windows/apps/codexu-tauri/web/tests/dashboard-source-hierarchy.test.mjs` — source-level regression guard for the single tab system and Leadership placement.
- Create: `windows/apps/codexu-tauri/web/tests/quota-overview-contract.test.mjs` — source-level regression guard for quota availability semantics and overview slots.
- Modify: `docs/windows-port/roadmap/phase-4-ui/DASHBOARD_SOURCE_HIERARCHY_ALIGNMENT_DESIGN.md` — change status from design approved to implementation verified only after all validation is complete.
- Modify: `docs/windows-port/roadmap/phase-4-ui/DASHBOARD_SOURCE_HIERARCHY_ALIGNMENT_DESIGN.html` — mirror the Markdown status change only after all validation is complete.

### Task 1: Introduce a single Dashboard content-tab owner

**Files:**
- Create: `windows/apps/codexu-tauri/web/tests/dashboard-source-hierarchy.test.mjs`
- Modify: `windows/apps/codexu-tauri/web/src/windows/Dashboard.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/DashboardHome.tsx`

**Interfaces:**
- Consumes: `CodexDashboardSnapshot.codex.snapshot`, `CodexDashboardSnapshot.codex.quota_source_label`, and `CodexDashboardSnapshot.leadership` already returned by `useUsage()`.
- Produces: `DashboardHome({ snapshot, quotaSourceLabel, leadershipSignal })`, where `snapshot` is `UsageSnapshot | null | undefined` and `quotaSourceLabel` is `string | null | undefined`.
- Produces: `type DashboardContentTab = 'tasks' | 'leadership' | 'usage' | 'projects' | 'skills'` in `DashboardHome.tsx`.

- [ ] **Step 1: Write the failing source-hierarchy test**

```js
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const dashboardPath = new URL('../src/windows/Dashboard.tsx', import.meta.url);
const homePath = new URL('../src/components/DashboardHome.tsx', import.meta.url);

test('keeps one macOS-ordered Dashboard tab system and relegates Leadership to its panel', async () => {
  const [dashboard, home] = await Promise.all([
    readFile(dashboardPath, 'utf8'),
    readFile(homePath, 'utf8'),
  ]);

  assert.doesNotMatch(dashboard, /type DashboardTab\s*=/);
  assert.doesNotMatch(dashboard, /<LeadershipPanel\b/);
  assert.doesNotMatch(dashboard, /<ThreadList\b/);
  assert.match(dashboard, /<DashboardHome[\s\S]*?snapshot=\{dashboard\?\.codex\?\.snapshot\}/);

  assert.match(home, /type DashboardContentTab\s*=\s*'tasks'\s*\|\s*'leadership'\s*\|\s*'usage'\s*\|\s*'projects'\s*\|\s*'skills'/);
  assert.match(home, /useState<DashboardContentTab>\('tasks'\)/);
  assert.match(home, /\{ id: 'tasks', title: 'Tasks' \}[\s\S]*?\{ id: 'leadership', title: 'AI Leadership' \}[\s\S]*?\{ id: 'usage', title: 'Usage' \}[\s\S]*?\{ id: 'projects', title: 'Projects' \}[\s\S]*?\{ id: 'skills', title: 'Skills' \}/);
  assert.match(home, /activeDashboardTab === 'leadership'[\s\S]*?<LeadershipPanel signal=\{signal\}/);
  assert.match(home, /setActiveDashboardTab\('leadership'\)/);
  assert.doesNotMatch(home, /LeadershipCommandRail/);
  assert.doesNotMatch(home, /Leadership facts/);
});
```

- [ ] **Step 2: Run the test and verify it fails against the current two-level navigation**

Run:

```powershell
node --test tests/dashboard-source-hierarchy.test.mjs
```

Expected: FAIL because `Dashboard.tsx` still declares the outer `DashboardTab`, and `DashboardHome.tsx` omits `leadership` from its lower tab type while rendering home-level leadership detail.

- [ ] **Step 3: Simplify the window shell and make `DashboardHome` the sole tab owner**

In `Dashboard.tsx`:

```tsx
<DashboardHome
  snapshot={dashboard?.codex?.snapshot}
  quotaSourceLabel={dashboard?.codex?.quota_source_label}
  leadershipSignal={dashboard?.leadership ?? null}
/>
```

Remove the outer `DashboardTab`, `TABS`, tab keyboard handler, `ThreadList`, `LeadershipPanel`, and all outer tab panels. Preserve the Header, local-only status line, loading/error states, and no-usage fallback.

In `DashboardHome.tsx`, replace `LowerTab` and `LOWER_TABS` with:

```tsx
type DashboardContentTab = 'tasks' | 'leadership' | 'usage' | 'projects' | 'skills';

const DASHBOARD_TABS: Array<{ id: DashboardContentTab; title: string }> = [
  { id: 'tasks', title: 'Tasks' },
  { id: 'leadership', title: 'AI Leadership' },
  { id: 'usage', title: 'Usage' },
  { id: 'projects', title: 'Projects' },
  { id: 'skills', title: 'Skills' },
];
```

Derive `usage` from `snapshot?.local`, keep the existing explicit Task and Skill unavailable copy, and render `LeadershipPanel` only when `activeDashboardTab === 'leadership'`. Replace the overview's direct detail button callback with a compact command button that calls `setActiveDashboardTab('leadership')`. Remove `LeadershipCommandRail`, the home-level Leadership facts section, and now-unused helpers/imports.

- [ ] **Step 4: Run the focused source-hierarchy regression test**

Run:

```powershell
node --test tests/dashboard-source-hierarchy.test.mjs
```

Expected: PASS. The test proves there is one tab owner, Tasks is default, the five macOS-order tabs exist, and leadership detail is nested in the leadership panel only.

- [ ] **Step 5: Build the web package and commit the navigation change**

Run:

```powershell
npm run build
git diff --check
git add src/windows/Dashboard.tsx src/components/DashboardHome.tsx tests/dashboard-source-hierarchy.test.mjs
git commit -m "refactor(windows-ui): unify dashboard navigation"
```

Expected: TypeScript/Vite build succeeds and the commit contains only the window shell, Dashboard content composition, and its focused regression test.

### Task 2: Add a truthful quota overview slot from existing snapshot data

**Files:**
- Create: `windows/apps/codexu-tauri/web/src/components/QuotaOverview.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/DashboardHome.tsx`
- Create: `windows/apps/codexu-tauri/web/tests/quota-overview-contract.test.mjs`

**Interfaces:**
- Consumes: `UsageSnapshot | null | undefined` and `quotaSourceLabel: string | null | undefined` supplied by Task 1.
- Produces: `QuotaOverview({ snapshot, sourceLabel })`.
- Does not call Tauri, mutate data, or compute a quota from token usage.

- [ ] **Step 1: Write the failing quota-contract test**

```js
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const quotaPath = new URL('../src/components/QuotaOverview.tsx', import.meta.url);
const homePath = new URL('../src/components/DashboardHome.tsx', import.meta.url);

test('renders quota only from the official snapshot and exposes an unavailable state otherwise', async () => {
  const [quota, home] = await Promise.all([
    readFile(quotaPath, 'utf8'),
    readFile(homePath, 'utf8'),
  ]);

  assert.match(quota, /snapshot\?\.quota_read_succeeded\s*===\s*true/);
  assert.match(quota, /snapshot\?\.five_hour_quota/);
  assert.match(quota, /snapshot\?\.seven_day_quota/);
  assert.match(quota, /sourceLabel \?\? 'Official quota unavailable on Windows'/);
  assert.doesNotMatch(quota, /today_tokens|seven_day_tokens|lifetime_tokens/);
  assert.match(home, /<QuotaOverview\s+snapshot=\{snapshot\}\s+sourceLabel=\{quotaSourceLabel\}/);
});
```

- [ ] **Step 2: Run the test and verify it fails because the component does not exist**

Run:

```powershell
node --test tests/quota-overview-contract.test.mjs
```

Expected: FAIL with `ENOENT` for `QuotaOverview.tsx`.

- [ ] **Step 3: Implement `QuotaOverview` with available and unavailable branches**

```tsx
interface QuotaOverviewProps {
  snapshot: UsageSnapshot | null | undefined;
  sourceLabel: string | null | undefined;
}

export function QuotaOverview({ snapshot, sourceLabel }: QuotaOverviewProps) {
  const hasOfficialQuota =
    snapshot?.quota_read_succeeded === true &&
    snapshot?.five_hour_quota != null &&
    snapshot?.seven_day_quota != null;

  if (!hasOfficialQuota) {
    return (
      <section className="dashboard-home-quota glass-panel p-4" aria-label="Quota availability">
        <h3 className="text-sm font-semibold text-primary">Quota</h3>
        <p className="mt-2 text-sm text-secondary">{sourceLabel ?? 'Official quota unavailable on Windows'}</p>
      </section>
    );
  }

  return (
    <section className="dashboard-home-quota glass-panel p-4" aria-label="Quota availability">
      <h3 className="text-sm font-semibold text-primary">Quota</h3>
      <div className="mt-3 grid grid-cols-2 gap-2">
        <QuotaWindow label="5h" window={snapshot.five_hour_quota} />
        <QuotaWindow label="7d" window={snapshot.seven_day_quota} />
      </div>
    </section>
  );
}

function QuotaWindow({ label, window }: { label: string; window: RateWindow }) {
  const percent = Math.min(100, Math.max(0, window.used_percent));
  return (
    <article className="rounded-lg border border-theme bg-surface-inset p-2">
      <p className="text-xs font-medium text-primary">{label}</p>
      <p className="mt-1 text-lg font-semibold text-primary">{percent.toFixed(0)}% used</p>
      <p className="mt-1 text-xs text-tertiary">{formatQuotaReset(window.resets_at)}</p>
    </article>
  );
}

function formatQuotaReset(value: number | null): string {
  return value == null ? 'Reset unavailable' : `Resets ${new Date(value).toLocaleString()}`;
}
```

Use only `RateWindow.used_percent`, `RateWindow.window_duration_mins`, and `RateWindow.resets_at` for the available branch. Clamp display percentages to `0..100`, present missing reset timestamps as `Unavailable`, and render no percentage when `quota_read_succeeded` is false. Add the component between the compact leadership command entry and the token-metric group in the overview.

- [ ] **Step 4: Run quota and source-hierarchy tests**

Run:

```powershell
node --test tests/quota-overview-contract.test.mjs tests/dashboard-source-hierarchy.test.mjs
```

Expected: PASS. The tests prove quota reads do not derive from local token totals and that the overview receives the existing snapshot/source-label pair.

- [ ] **Step 5: Build and commit the quota presentation boundary**

Run:

```powershell
npm run build
git diff --check
git add src/components/QuotaOverview.tsx src/components/DashboardHome.tsx tests/quota-overview-contract.test.mjs
git commit -m "feat(windows-ui): add quota availability overview"
```

Expected: Build succeeds; no Rust, IPC, or model file is staged.

### Task 3: Recompose the overview with source-order grid areas

**Files:**
- Modify: `windows/apps/codexu-tauri/web/src/components/DashboardHome.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/index.css`
- Modify: `windows/apps/codexu-tauri/web/tests/dashboard-source-hierarchy.test.mjs`

**Interfaces:**
- Consumes: `QuotaOverview`, the compact leadership command button, current Today/7-Day/Lifetime `StatCard`s, and `MonthlyValueProgress`.
- Produces: `.dashboard-home-overview` with `.dashboard-home-command`, `.dashboard-home-quota`, `.dashboard-home-metrics`, and `.dashboard-home-monthly` areas.

- [ ] **Step 1: Extend the failing hierarchy test with grid-order assertions**

```js
const stylesheetPath = new URL('../src/index.css', import.meta.url);
const stylesheet = await readFile(stylesheetPath, 'utf8');

assert.match(home, /className="dashboard-home-overview"/);
assert.match(home, /className="dashboard-home-command"/);
assert.match(home, /className="dashboard-home-monthly"/);
assert.match(stylesheet, /\.dashboard-home-overview\s*\{[\s\S]*?grid-template-areas:\s*"command"\s*"quota"\s*"metrics"\s*"month"/);
assert.match(stylesheet, /@media \(min-width: 930px\)\s*\{[\s\S]*?grid-template-areas:\s*"command quota metrics"\s*"command quota month"/);
assert.match(stylesheet, /\.dashboard-home-command\s*\{[\s\S]*?grid-area:\s*command/);
assert.match(stylesheet, /\.dashboard-home-quota\s*\{[\s\S]*?grid-area:\s*quota/);
assert.match(stylesheet, /\.dashboard-home-metrics\s*\{[\s\S]*?grid-area:\s*metrics/);
assert.match(stylesheet, /\.dashboard-home-monthly\s*\{[\s\S]*?grid-area:\s*month/);
```

- [ ] **Step 2: Run the test and verify it fails before the grid-area migration**

Run:

```powershell
node --test tests/dashboard-source-hierarchy.test.mjs
```

Expected: FAIL because neither the overview container nor the required compact/mobile and desktop grid areas exist.

- [ ] **Step 3: Implement the source-order overview markup and CSS**

Replace the current equal-width `dashboard-home-top-grid` wrapper with this order in `DashboardHome.tsx`:

```tsx
<div className="dashboard-home-overview">
  <button
    className="dashboard-home-command glass-panel p-4"
    type="button"
    aria-controls="dashboard-home-panel-leadership"
    onClick={() => setActiveDashboardTab('leadership')}
  >
    <LeadershipOrbit score={scoreForVisual} activeBand={activeBand} hasSignal={hasSignal} />
    <span className="text-sm font-semibold text-primary">AI Leadership</span>
  </button>
  <QuotaOverview snapshot={snapshot} sourceLabel={quotaSourceLabel} />
  <section className="dashboard-home-metrics" aria-label="Local token metrics">
    <StatCard
      label="Today"
      value={formatNumber(usage?.today_tokens)}
      subValue={usage?.detailed_usage ? `$${formatUSD(usage.detailed_usage.today.estimated_cost_usd)} est.` : 'Record insufficient'}
      icon={<Activity size={16} />}
      compact
      accent="primary"
    />
    <StatCard
      label="7-Day"
      value={formatNumber(usage?.seven_day_tokens)}
      subValue={usage?.detailed_usage ? `$${formatUSD(usage.detailed_usage.seven_day.estimated_cost_usd)} est.` : 'Record insufficient'}
      icon={<Calendar size={16} />}
      compact
      accent="secondary"
    />
    <StatCard
      label="Lifetime"
      value={formatNumber(usage?.lifetime_tokens)}
      subValue={usage?.detailed_usage ? `$${formatUSD(usage.detailed_usage.lifetime.estimated_cost_usd)} est.` : 'Record insufficient'}
      icon={<TrendingUp size={16} />}
      compact
      accent="tertiary"
    />
  </section>
  <div className="dashboard-home-monthly"><MonthlyValueProgress usage={usage} /></div>
</div>
```

Implement the stylesheet using existing surface, border, text, and quota tokens:

```css
.dashboard-home-overview {
  display: grid;
  grid-template-areas: "command" "quota" "metrics" "month";
  gap: 0.75rem;
}
.dashboard-home-command { grid-area: command; }
.dashboard-home-quota { grid-area: quota; }
.dashboard-home-metrics { grid-area: metrics; }
.dashboard-home-monthly { grid-area: month; }

@media (min-width: 930px) {
  .dashboard-home-overview {
    grid-template-columns: minmax(154px, 0.72fr) minmax(154px, 0.72fr) minmax(0, 2.1fr);
    grid-template-areas: "command quota metrics" "command quota month";
    align-items: stretch;
  }
  .dashboard-home-metrics { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
```

Remove superseded `.dashboard-home-top-grid`, home-level rail, and home-level leadership-facts layout rules. Keep the existing `LeadershipPanel` stylesheet untouched except where a selector only targeted the removed home-level content.

- [ ] **Step 4: Run the focused tests and web build**

Run:

```powershell
node --test tests/dashboard-source-hierarchy.test.mjs tests/quota-overview-contract.test.mjs tests/leadership-rail-layout.test.mjs
npm run build
```

Expected: all Node tests and the TypeScript/Vite build PASS. The rail test proves moving the rail did not reintroduce coordinate-frame regressions.

- [ ] **Step 5: Commit the layout composition**

Run:

```powershell
git diff --check
git add src/components/DashboardHome.tsx src/index.css tests/dashboard-source-hierarchy.test.mjs
git commit -m "feat(windows-ui): align dashboard overview hierarchy"
```

Expected: only the overview composition, its CSS, and regression assertions are staged.

### Task 4: Validate native behavior and update the approved design status

**Files:**
- Modify: `docs/windows-port/roadmap/phase-4-ui/DASHBOARD_SOURCE_HIERARCHY_ALIGNMENT_DESIGN.md`
- Modify: `docs/windows-port/roadmap/phase-4-ui/DASHBOARD_SOURCE_HIERARCHY_ALIGNMENT_DESIGN.html`

**Interfaces:**
- Consumes: the complete implementation and the existing `codexu-tauri.exe` release target.
- Produces: a verified native Windows screenshot and matching Markdown/HTML design-status evidence.

- [ ] **Step 1: Run all static, web, Rust, and diff validation**

Run:

```powershell
Set-Location E:\project\codexU\windows\apps\codexu-tauri\web
node --test tests/dashboard-source-hierarchy.test.mjs tests/quota-overview-contract.test.mjs tests/leadership-rail-layout.test.mjs
npm run build
Set-Location E:\project\codexU\windows
cargo test --workspace
cargo tauri build --no-bundle
Set-Location E:\project\codexU
git diff --check
```

Expected: all commands PASS. If the Tauri rebuild reports `os error 5`, inspect the active process and close only `windows/target/release/codexu-tauri.exe`, then rebuild; do not terminate unrelated processes.

- [ ] **Step 2: Inspect the freshly rebuilt native app**

Launch only the rebuilt `E:\project\codexU\windows\target\release\codexu-tauri.exe`. Confirm visually that:

1. The top overview has a compact leadership entry, quota availability slot, three token cards, and month progress.
2. Today tasks is the active lower tab at launch.
3. The lower tab order is Tasks, AI Leadership, Usage, Projects, Skill.
4. Selecting the compact leadership entry opens AI Leadership in the lower panel.
5. The command rail, leadership dimensions, and leadership trend are absent from the top overview and present only in AI Leadership.
6. The current Windows quota fallback says it is unavailable rather than showing a fabricated percentage.

Capture a new screenshot only after those checks pass. Do not reuse a prior screenshot or claim native visual acceptance if the check is interrupted.

- [ ] **Step 3: Update the paired design status and commit final verification evidence**

Change the Markdown and HTML status from `Approved design; implementation not started` to `Implemented and validated` only if every command and all six visual checks passed. Add the exact command outcomes and screenshot path to both documents.

Run:

```powershell
git diff --check
git add docs/windows-port/roadmap/phase-4-ui/DASHBOARD_SOURCE_HIERARCHY_ALIGNMENT_DESIGN.md docs/windows-port/roadmap/phase-4-ui/DASHBOARD_SOURCE_HIERARCHY_ALIGNMENT_DESIGN.html
git commit -m "docs(windows): record dashboard hierarchy validation"
git status --short
```

Expected: the final commit contains only the paired validation evidence. Existing untracked architecture-review files remain untouched.

## Plan Self-Review

- Spec coverage: Task 1 covers one macOS-order tab system and the default Tasks state. Task 2 covers the existing official-quota contract and explicit unavailable behavior. Task 3 covers source-order desktop/compact composition and prevents home-level Leadership detail. Task 4 covers all required builds, rail regression, native review, screenshot freshness, and paired documentation status.
- Placeholder review: no unresolved markers or postponed implementation phrases remain; every task names files, commands, failure conditions, interfaces, and implementation details.
- Type consistency: `DashboardHome` consistently consumes `UsageSnapshot | null | undefined`, `quotaSourceLabel`, and `CodexLeadershipSignal | null | undefined`; `QuotaOverview` consumes the same snapshot and source-label pair without a new backend contract.
