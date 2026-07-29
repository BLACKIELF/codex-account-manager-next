# CODEX Dashboard Snapshot Refactor Design

- Status: implemented and accepted for the Codex-only Windows Dashboard contract.
- Date: 2026-07-28
- Scope: one local Codex snapshot pipeline for Tauri; no Claude provider, selector, or synthetic quota surface.

## Design outcome

The Windows Dashboard no longer treats `LocalUsage` as its top-level IPC response. Its implemented responsibility chain is:

```text
local Codex state_5.sqlite + local rollout/session JSONL
  -> CodexDashboardProvider
  -> CodexDashboardSnapshot
  -> source-keyed, single-flight AppState cache + Tauri IPC
  -> web useUsage() + Dashboard consumers
```

`CodexDashboardProvider` is the only enabled provider for this surface. It reads local state metadata when available, parses cached local session summaries, then creates two independent branches:

1. `make_local_usage(...)` produces local telemetry for `codex.snapshot.local`.
2. `build_leadership_snapshot(...)` produces a leadership report; `CodexLeadershipSignal` carries the selected period's score, coverage, active-day count, model version, and report.

The provider assembles those branches into one `CodexDashboardSnapshot`. AppState serializes refreshes, keys cached data by Codex source configuration/generation, and returns the same snapshot shape through `get_local_usage` and `refresh_usage`. The web hook consumes that snapshot directly; it does not reconstruct a usage response from raw reader fields.

## Contract boundary

```rust
CodexDashboardSnapshot {
  codex: RuntimeUsageSnapshot,
  leadership: CodexLeadershipSignal,
  refreshed_at,
  messages,
}
```

- `codex` is explicitly `RuntimeScope::Codex` and `RuntimeMenuStatus::LocalOnly`.
- Local metrics remain nested at `codex.snapshot.local`; they are not promoted to a second top-level IPC object.
- The runtime advertises that official quota is unavailable on Windows. Quota windows are `None` and `quota_read_succeeded` is false; the UI must not invent quota, allowance, remaining balance, or billing values.
- UI-facing messages are source-safe. If state metadata is unavailable, the provider reports a generic local-metadata warning rather than exposing paths or low-level database diagnostics.
- The scope does not enable Claude Code. Existing generic/runtime types do not constitute an active Claude provider, a runtime selector, or a Claude Dashboard claim.

## Leadership integrity

Leadership is a branch separate from local token aggregation. Session parsing preserves task-interval evidence, including explicit `task_started` / `task_complete` intervals and valid derived-duration intervals. The leadership report computes its own dimensions, evidence coverage, active-day count, maturity, score, and title.

Score visibility is gated rather than inferred from token totals:

- all four dimensions must be available;
- active days must be positive;
- evidence coverage must reach `0.70`;
- the signal's model version must be non-stub;
- maturity prevents an unwarranted perfect score before 28 active days or weak coverage.

When the report does not yield a valid score, `leadership.score` is `null`; UI consumers render an insufficient/pending state. A title comes from the report for the selected period, not from a UI-generated label or a raw usage heuristic.

## Privacy and presentation constraints

- Inputs remain local Codex state and local transcript data.
- Dashboard payloads and fixed overview do not expose prompt/response bodies, raw tool arguments, credentials, or absolute paths.
- Token mix is local telemetry, not an official quota or bill. The Month value surface remains a local estimate, not a strict macOS Wool equivalent.

## Native evidence and validation

Accepted final release evidence uses HWND-specific `PrintWindow`; it is a non-Computer-Use native capture. The three valid assets are:

- [default Dashboard](../../reports/assets/codex-dashboard-snapshot-default-native.png)
- [AI Leadership detail](../../reports/assets/codex-dashboard-snapshot-leadership-native.png)
- [lower Dashboard navigation](../../reports/assets/codex-dashboard-snapshot-lower-tabs-native.png)

Capture bounds were `1462x1196` physical pixels at DPI 144, approximately `975x797 CSS px`.

- Default: exactly three global tabs, full L1-L7 rail, and a Token mix of `1,784,569,471` input + `1,706,410,112` cached input + `9,142,958` output = `3,500,122,541`, with no raw body content.
- Leadership: identity, score, rail, and metrics are visible in the detail hierarchy.
- Lower navigation: pure Win32 `SendInput` PageDown plus wheel scrolling, then `PW_RENDERFULLCONTENT`, shows readable L1-L7, local API-equivalent Month value / not official quota, and one Tasks / Usage / Projects / Skills tab bar. It proves navigation hierarchy only, not variable-panel internals or strict cross-platform equivalence.

Final validation:

| Check | Result |
| --- | --- |
| `npm run build` | pass |
| `cargo test --workspace` | pass: 35 core + 7 Tauri tests |
| `cargo tauri build --no-bundle` | pass; release EXE built 2026-07-28 04:23:36 Asia/Shanghai |
| `git diff --check` | pass |

## Non-goals

- No Claude runtime implementation or selector.
- No official quota reader, fake quota, points change, or remote service.
- No change to the meaning of local telemetry as a capture-time local record.
