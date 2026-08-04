# Windows Codex Quota Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display the official Codex account quota returned by the local Codex app-server on Windows, preserve a last verified result through a transient read failure, and never present transcript-derived Token totals as quota.

**Architecture:** The existing local transcript provider remains responsible for local usage and leadership. A focused app-server reader launches the installed Codex CLI on a temporary loopback WebSocket port, sends only read-only account requests, normalizes official rate windows by duration, and merges the result into the dashboard snapshot. The UI renders every returned official window independently and offers a retry state before the first successful read.

**Tech Stack:** Rust, Tokio, tokio-tungstenite, Tauri 2, React, TypeScript, Node test runner.

## Global Constraints

- Use `account/rateLimits/read` only; never call rate-limit credit consumption or any account mutation.
- Bind app-server only to `127.0.0.1` and terminate its child process after each bounded refresh.
- Treat `300`, `10080`, and 28-31 day durations as 5-hour, 7-day, and monthly windows; never infer a missing window.
- Keep local transcript usage labelled local and never synthesize an official quota percentage from it.
- Preserve only the latest verified official snapshot after a failed read and clearly label it as stale.
- Do not alter unrelated Dashboard hierarchy or existing dirty UI work.

---

### Task 1: Add a testable Codex app-server quota reader

**Files:**

- Create: `windows/crates/codexu-core/src/readers/codex_app_server.rs`
- Modify: `windows/crates/codexu-core/src/readers/mod.rs`
- Modify: `windows/Cargo.toml`
- Modify: `windows/crates/codexu-core/Cargo.toml`
- Test: `windows/crates/codexu-core/src/readers/codex_app_server.rs`

**Interfaces:**

- Consumes: JSON-RPC results from `account/read` and `account/rateLimits/read` over a `ws://127.0.0.1:<port>` Codex app-server.
- Produces: `CodexAppServerQuotaSnapshot`, containing account metadata, selected limit metadata, `quota_read_succeeded`, and normalized 5-hour/7-day/monthly `RateWindow` values.

- [ ] **Step 1: Write the failing parser tests**

```rust
#[test]
fn normalizes_a_single_weekly_window_as_an_authoritative_quota() {
    let parsed = parse_rate_limits(json!({
        "rateLimits": {"primary": {"usedPercent": 41, "windowDurationMins": 10080, "resetsAt": 1_800_000_000}}
    }));
    assert!(parsed.quota_read_succeeded);
    assert!(parsed.five_hour_quota.is_none());
    assert_eq!(parsed.seven_day_quota.unwrap().used_percent, 41.0);
}
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `cargo test -p codexu-core codex_app_server::tests::normalizes_a_single_weekly_window_as_an_authoritative_quota`

Expected: FAIL because the module and parser do not exist.

- [ ] **Step 3: Implement the minimal reader and parser**

```rust
pub async fn read_quota(&self) -> CodexAppServerQuotaSnapshot {
    let mut client = self.connect_loopback_app_server().await?;
    client.initialize().await?;
    client.request("account/read", json!({"refreshToken": false})).await?;
    parse_rate_limits(client.request("account/rateLimits/read", Value::Null).await?)
}
```

The reader must select `rateLimitsByLimitId.codex` when it exists, fall back to `rateLimits`, parse only numeric `usedPercent` windows, use the existing duration normalizer, and return an unavailable result with a non-sensitive diagnostic on timeout, launch, or protocol failure.

- [ ] **Step 4: Run the focused reader tests**

Run: `cargo test -p codexu-core codex_app_server::tests`

Expected: PASS, covering weekly-only, five-hour-only, monthly-only, duplicate duration, malformed response, and `rateLimitsByLimitId.codex` selection.

- [ ] **Step 5: Commit the reader task**

```bash
git add windows/Cargo.toml windows/crates/codexu-core/Cargo.toml windows/crates/codexu-core/src/readers/codex_app_server.rs windows/crates/codexu-core/src/readers/mod.rs
git commit -m "feat(windows): read Codex quota through app-server"
```

### Task 2: Merge official quota into the dashboard with stale continuity

**Files:**

- Modify: `windows/crates/codexu-core/src/readers/codex_dashboard.rs`
- Modify: `windows/apps/codexu-tauri/src-tauri/src/app_state.rs`
- Test: `windows/crates/codexu-core/src/readers/codex_dashboard.rs`
- Test: `windows/apps/codexu-tauri/src-tauri/src/app_state.rs`

**Interfaces:**

- Consumes: local `CodexDashboardSnapshot`, `CodexAppServerQuotaSnapshot`, and the prior cached dashboard.
- Produces: a dashboard snapshot whose `RuntimeMenuStatus` is `Available` after an authoritative read, `Stale` after retaining a previous authoritative quota, or `LocalOnly` before the first successful quota read.

- [ ] **Step 1: Write failing merge tests**

```rust
#[test]
fn applies_an_authoritative_weekly_quota_without_creating_a_five_hour_window() {
    let dashboard = apply_quota(local_dashboard(), weekly_quota());
    assert!(dashboard.codex.snapshot.quota_read_succeeded);
    assert!(dashboard.codex.snapshot.five_hour_quota.is_none());
    assert_eq!(dashboard.codex.status, RuntimeMenuStatus::Available);
}

#[test]
fn retains_the_previous_quota_as_stale_after_a_read_failure() {
    let refreshed = retain_verified_quota(previous_official_dashboard(), failed_quota_dashboard());
    assert_eq!(refreshed.codex.status, RuntimeMenuStatus::Stale);
    assert!(refreshed.codex.snapshot.seven_day_quota.is_some());
}
```

- [ ] **Step 2: Run the focused tests to verify they fail**

Run: `cargo test -p codexu-core codex_dashboard::tests::applies_an_authoritative_weekly_quota_without_creating_a_five_hour_window` and `cargo test -p codexu-tauri retains_the_previous_quota_as_stale_after_a_read_failure`

Expected: FAIL because no merge or continuity function exists.

- [ ] **Step 3: Implement the merge at the source boundary**

```rust
let local_dashboard = provider.load_dashboard_snapshot(now).await?;
let dashboard = local_dashboard.map(|value| apply_quota(value, quota_reader.read().await));
let dashboard = retain_verified_quota(previous_dashboard.as_ref(), dashboard);
```

Keep `quota_read_succeeded` true only for an authoritative current response. A retained prior result must keep its actual windows, use `RuntimeMenuStatus::Stale`, and use a label such as `Official Codex quota - last verified`.

- [ ] **Step 4: Run the Rust regression suites**

Run: `cargo test --workspace`

Expected: PASS, including existing local-usage and source-generation cache tests.

- [ ] **Step 5: Commit the integration task**

```bash
git add windows/crates/codexu-core/src/readers/codex_dashboard.rs windows/apps/codexu-tauri/src-tauri/src/app_state.rs
git commit -m "feat(windows): retain verified Codex quota"
```

### Task 3: Render all official window topologies and a first-read retry state

**Files:**

- Modify: `windows/apps/codexu-tauri/web/src/components/QuotaOverview.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/DashboardHome.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/windows/Dashboard.tsx`
- Modify: `windows/apps/codexu-tauri/web/tests/quota-overview-contract.test.mjs`
- Test: `windows/apps/codexu-tauri/web/tests/quota-overview-contract.test.mjs`

**Interfaces:**

- Consumes: individual `five_hour_quota`, `seven_day_quota`, and `monthly_quota` values plus `RuntimeMenuStatus` and an `onRefresh` callback.
- Produces: visible official windows for every populated duration, a stale label for a retained verified snapshot, or `Checking official Codex quota` with a retry button before any successful read.

- [ ] **Step 1: Write the failing UI contract tests**

```javascript
assert.match(quota, /five_hour_quota/);
assert.match(quota, /seven_day_quota/);
assert.match(quota, /monthly_quota/);
assert.doesNotMatch(quota, /five_hour_quota != null && snapshot\?\.seven_day_quota != null/);
assert.match(quota, /Checking official Codex quota/);
assert.match(home, /onQuotaRefresh/);
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `node --test tests/quota-overview-contract.test.mjs`

Expected: FAIL because the current component requires both 5-hour and 7-day windows and has no retry state.

- [ ] **Step 3: Implement the minimal presentation change**

```tsx
const windows = [
  ['5h', snapshot?.five_hour_quota],
  ['7d', snapshot?.seven_day_quota],
  ['Monthly', snapshot?.monthly_quota],
].filter(([, value]) => value != null);
```

Render any non-empty official window list. When it is empty, show only a neutral checking state and route its `Retry quota check` button to `useUsage().refresh`; do not call local Token totals or display `Unavailable` as the default state.

- [ ] **Step 4: Run web verification**

Run: `node --test tests/dashboard-source-hierarchy.test.mjs tests/quota-overview-contract.test.mjs tests/leadership-rail-layout.test.mjs` then `npm run build`

Expected: PASS.

- [ ] **Step 5: Commit the UI task**

```bash
git add windows/apps/codexu-tauri/web/src/components/QuotaOverview.tsx windows/apps/codexu-tauri/web/src/components/DashboardHome.tsx windows/apps/codexu-tauri/web/src/windows/Dashboard.tsx windows/apps/codexu-tauri/web/tests/quota-overview-contract.test.mjs
git commit -m "feat(windows-ui): activate official quota overview"
```

### Task 4: Align the documented boundary and prove the activation

**Files:**

- Modify: `docs/windows-port/roadmap/phase-4-ui/DASHBOARD_HOME_DESIGN.md`
- Create: `docs/windows-port/reports/WINDOWS_QUOTA_ACTIVATION_REPORT.md`
- Create: `docs/windows-port/reports/WINDOWS_QUOTA_ACTIVATION_REPORT.html`

**Interfaces:**

- Consumes: test/build output and a sanitized live app-server probe result.
- Produces: matching Markdown and HTML evidence explaining the official path, stale behavior, local-only boundary, verification, and remaining live-UI limits.

- [ ] **Step 1: Update the design boundary**

Replace the superseded statement that Windows does not read official quota with the app-server reader, duration-normalization, loopback-only, stale-continuity, and local-token non-equivalence rules.

- [ ] **Step 2: Capture sanitized live evidence**

Run the reader against the installed Codex CLI and record only response topology (for example, `7d returned`), never account data, tokens, paths, or raw protocol payloads.

- [ ] **Step 3: Produce matching reports**

Write the same verdict, verified checks, known gaps, and no-fabrication boundary into both report files. The HTML report must be a static browser-readable rendering of the Markdown content.

- [ ] **Step 4: Run final gates**

Run: `cargo test --workspace`, `npm run build`, `cargo tauri build --no-bundle`, and `git diff --check`.

Expected: all commands PASS; if the executable is locked, close only `windows/target/release/codexu-tauri.exe` before repeating the bundle build.

- [ ] **Step 5: Commit the documentation task**

```bash
git add docs/windows-port/roadmap/phase-4-ui/DASHBOARD_HOME_DESIGN.md docs/windows-port/reports/WINDOWS_QUOTA_ACTIVATION_REPORT.md docs/windows-port/reports/WINDOWS_QUOTA_ACTIVATION_REPORT.html
git commit -m "docs(windows): document quota activation"
```

## Plan Self-Review

- Coverage: Tasks 1-2 implement the official source and stale continuity; Task 3 removes the double-window UI gate and adds retry; Task 4 updates the superseded design promise and supplies paired verification evidence.
- Placeholder scan: no implementation, test, or validation step is deferred to an unspecified task.
- Type consistency: `CodexAppServerQuotaSnapshot` feeds the dashboard merge, while `RuntimeMenuStatus`, per-duration `RateWindow` fields, and `onQuotaRefresh` cross the backend/UI boundary explicitly.

## Execution Handoff

This user-directed task will use inline execution in the current session because the repository policy forbids proactive subagent delegation.
