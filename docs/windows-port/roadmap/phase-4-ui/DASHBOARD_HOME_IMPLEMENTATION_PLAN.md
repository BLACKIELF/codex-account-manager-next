# Windows Dashboard Home Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a real default Windows Dashboard that applies the macOS reference's information hierarchy using only existing truthful local data, then document it with a real-screenshot showcase.

**Architecture:** `Dashboard.tsx` keeps data loading and tab state; a presentation-only `DashboardHome` composes reusable Leadership, Token, summary, and chart surfaces. The scope does not add rate-limit ingestion: central usage is an explicitly labelled seven-day Token composition. The static showcase is generated from native acceptance screenshots only.

**Tech Stack:** React, TypeScript, Tailwind utilities, existing CSS variables, Lucide icons, Recharts, Rust/Tauri build verification.

## Global Constraints

- Keep local-first and privacy boundaries; never expose raw threads, prompts, responses, tool arguments, paths, or account data.
- Reuse existing palette/app-theme CSS variables, components, and Leadership badge resources; no new UI library or scattered hard-coded design values.
- Preserve score calculations, caching, local data readers, thread parsing, and IPC semantics. Do not add official quota fields in this scope.
- Keep light/system Windows presentation, Liquid Glass material, system typography, semantic colors, and reduced-motion behavior.
- Do not commit generated `build/`, `dist/`, or `.build/` output. Do not push or merge.

---

### Task 1: Add the default Dashboard-home navigation contract

**Files:**
- Modify: `windows/apps/codexu-tauri/web/src/windows/Dashboard.tsx`
- Test: `windows/apps/codexu-tauri/web/package.json` build script

**Interfaces:**
- Consumes: `useUsage(): { usage, loading, error, refresh }` and existing `DashboardTab` keyboard navigation.
- Produces: `DashboardTab` with `home` as the default; all existing detailed tabs remain addressable.

- [ ] **Step 1: Define the expected route state before editing**

Record the route invariant in the task diff: `activeTab` initially equals `'home'`; the tab order is Dashboard, AI Leadership, Usage, Threads, Projects; ArrowLeft/ArrowRight continues to operate over the complete tab array.

- [ ] **Step 2: Implement the minimal tab update**

Extend the union and `TABS` array with `home`. Add a `role="tabpanel"` branch that passes the existing `usage`, loading state, Leadership snapshot, and a `() => setActiveTab('leadership')` callback into `DashboardHome`. Do not alter `useUsage`, Tauri invokes, or existing detail branches.

- [ ] **Step 3: Run the frontend type/build check**

Run: `npm run build` from `windows/apps/codexu-tauri/web`
Expected: Vite production build succeeds; no TypeScript error for the new tab union or component props.

### Task 2: Compose the truthful Dashboard home

**Files:**
- Create: `windows/apps/codexu-tauri/web/src/components/DashboardHome.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/LeadershipPanel.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/index.css`
- Test: `windows/apps/codexu-tauri/web/package.json` build script

**Interfaces:**
- Consumes: `LocalUsage`, `LeadershipDashboardSnapshot | null`, existing `StatCard`, `TokenBarChart`, `TrendChart`, `LEADERSHIP_BANDS`, and CSS semantic variables.
- Produces: `DashboardHome({ usage, leadership, onOpenLeadership })` with no Tauri invokes or score calculations; reusable compact Leadership overview/progression primitives where extracting them removes duplicate mapping.

- [ ] **Step 1: Establish visual acceptance before styling**

At a 960×760 native window, the first viewport must contain three aligned top groups: Leadership identity, seven-day Token mix, and Today/7-day/Lifetime summaries. The full-width L1–L7 progression follows them, then the chart row. Missing detailed usage shows `Record insufficient`/`--`, never `0` or a fake percentage.

- [ ] **Step 2: Implement the presentation-only composition**

Build a compact Leadership summary from the canonical `resolveLeadershipBand` mapping and existing badge assets. Render an accessible button that calls `onOpenLeadership`; valid signals show the real title/score/metrics, invalid signals use the neutral state. Render a seven-day Token mix with the existing `DetailedUsage.seven_day.tokens` fields and labels `Input`, `Cached input`, and `Output`; use proportional segments only when their sum is positive and label the group `7-day Token mix`, never quota or remaining allowance. Reuse existing `StatCard`, `TokenBarChart`, and `TrendChart` rather than duplicate their data calculations.

- [ ] **Step 3: Implement stable layout tokens**

Add only reusable Dashboard-home class rules to `index.css`: a fixed desktop grid that collapses in the documented order, aligned panels, a shared glass surface, and the existing semantic quota/data colors. Do not add background orbs, a dark promotional background, emoji, or new hard-coded color/spacing systems.

- [ ] **Step 4: Run the frontend build check**

Run: `npm run build` from `windows/apps/codexu-tauri/web`
Expected: Vite build succeeds and no unused/invalid TypeScript imports remain.

### Task 3: Preserve Leadership detail and create native acceptance evidence

**Files:**
- Modify: `windows/apps/codexu-tauri/web/src/components/LeadershipPanel.tsx` only if a compact primitive extraction is required by Task 2
- Create: `docs/windows-port/reports/assets/dashboard-home-native.png`
- Create: `docs/windows-port/reports/assets/dashboard-home-leadership-detail.png`
- Test: native Windows release executable

**Interfaces:**
- Consumes: final web bundle embedded by Tauri.
- Produces: native screenshots proving both default Dashboard home and detailed Leadership view.

- [ ] **Step 1: Build the packaged frontend**

Run: `cargo tauri build --no-bundle` from `windows/apps/codexu-tauri/src-tauri`
Expected: success and a release executable at `windows/target/release/codexu-tauri.exe`. If a running executable causes `os error 5`, close only that exact target process and rerun once.

- [ ] **Step 2: Capture and inspect native evidence**

Launch exactly one release executable, capture the Dashboard home and Leadership detail around 960×760, and inspect both screenshots. Verify: no clipping; tab focus is clear; badge/threshold mapping is visible; the Token mix is not phrased as quota; the existing detailed rail still uses its full-domain clipped gradient.

- [ ] **Step 3: Run full regression commands**

Run: `cargo test --workspace` from `windows`; then `git diff --check` from the repository root.
Expected: all core tests pass and the diff has no whitespace errors.

### Task 4: Publish a truthful static showcase and update parity evidence

**Files:**
- Create: `docs/windows-port/showcase/WINDOWS_DASHBOARD_SHOWCASE.md`
- Create: `docs/windows-port/showcase/WINDOWS_DASHBOARD_SHOWCASE.html`
- Modify: `docs/windows-port/reports/WINDOWS_UI_PARITY_REPORT.md`
- Modify: `docs/windows-port/reports/WINDOWS_UI_PARITY_REPORT.html`
- Test: `git diff --check`

**Interfaces:**
- Consumes: only final native screenshots from Task 3 and observed command results.
- Produces: an editable Markdown source plus browser-readable HTML that agree on evidence, validation, platform differences, and known gaps.

- [ ] **Step 1: Write the Markdown showcase from final evidence**

Document the top-level hierarchy mapping, resource reuse, actual data labels, screenshots, tests, and retained differences. State that the Windows home uses real local Token mix instead of official quota because the active UI contract does not expose rate-limit snapshots. Do not call it pixel-perfect parity or claim a web deployment.

- [ ] **Step 2: Create the matching static HTML showcase**

Use the same verdict, numbers, screenshots, known gaps, and next steps as the Markdown source. Keep it browser-readable and self-contained apart from local screenshot links.

- [ ] **Step 3: Update the parity report without overstating completion**

Change the report classification from component-level rail parity to page-level Dashboard hierarchy alignment only if the native screenshots prove it. Retain any missing official quota/empty-state coverage as explicit platform or scope gaps.

- [ ] **Step 4: Run documentation validation**

Run: `git diff --check` from the repository root.
Expected: no whitespace errors; Markdown and HTML use the same conclusions and validation facts.

### Task 5: Review the final diff and prepare a reviewable commit

**Files:**
- Review: all files changed by Tasks 1–4

**Interfaces:**
- Consumes: successful build/test results and native screenshots.
- Produces: one focused, reviewable Dashboard-home change set; no push or merge.

- [ ] **Step 1: Inspect staging scope**

Run: `git diff --name-status` and then `git diff --cached --name-status` after staging. Confirm paths are limited to Dashboard-home components/styles, screenshots, showcase/report pairs, and this roadmap plan if retained.

- [ ] **Step 2: Verify final repository state**

Run: `git status --short --branch`; confirm no generated `build/`, `dist/`, or `.build/` artifacts are staged.

- [ ] **Step 3: Prepare, but do not push**

Use the suggested commit message `feat(windows-ui): compose dashboard home` only after native visual acceptance. Do not push, merge, or alter `main`.
