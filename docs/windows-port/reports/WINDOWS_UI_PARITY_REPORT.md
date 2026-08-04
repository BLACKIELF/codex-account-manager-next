# Windows UI Parity Report: Codex Dashboard Snapshot

- Report date: 2026-07-28
- Verdict: accepted for the Codex-only snapshot architecture and compact Dashboard hierarchy. This is not a macOS pixel, quota, or numeric-parity claim.

## Acceptance conclusion

- The implemented path is local Codex sources -> `CodexDashboardProvider` -> `CodexDashboardSnapshot` -> source-safe AppState/Tauri IPC -> web Dashboard.
- The nested runtime remains `Codex` / local-only. `snapshot.codex.snapshot.local` carries local telemetry; official quota fields are not faked.
- Leadership is independent from usage aggregation. Its report/score is evidence-gated and a missing score stays null/pending.
- The default Dashboard shows exactly three global tabs, a full L1-L7 rail, and a three-part local Token mix without raw body content.
- AI Leadership detail shows identity, score, rail, and metrics as a drill-down hierarchy.

## Native evidence

Native acceptance used non-Computer-Use HWND `PrintWindow` capture. All three valid images were captured at `1462x1196` physical pixels / DPI 144, approximately `975x797 CSS px`. The lower-tabs frame used pure Win32 `SendInput` PageDown plus wheel scrolling, followed by `PW_RENDERFULLCONTENT`; it did not use Computer Use, UIA, or Playwright.

| Surface | Evidence | Accepted fact |
| --- | --- | --- |
| Default Dashboard | [codex-dashboard-snapshot-default-native.png](assets/codex-dashboard-snapshot-default-native.png) | Three global tabs; complete L1-L7; `1,784,569,471 + 1,706,410,112 + 9,142,958 = 3,500,122,541` Token mix; no raw body content. |
| AI Leadership | [codex-dashboard-snapshot-leadership-native.png](assets/codex-dashboard-snapshot-leadership-native.png) | Identity, evidence-gated score, rail, and metrics. |
| Lower Dashboard navigation | [codex-dashboard-snapshot-lower-tabs-native.png](assets/codex-dashboard-snapshot-lower-tabs-native.png) | Readable L1-L7, local API-equivalent Month value / not official quota, and one Tasks / Usage / Projects / Skills tab bar. |

The lower-tabs image is accepted evidence for current navigation hierarchy and the single tab bar only. It does not establish variable-panel internals or strict cross-platform feature equivalence.

## Cross-platform interpretation

| Area | Windows conclusion | Boundary |
| --- | --- | --- |
| Fixed overview / AI Leadership | Accepted hierarchy correspondence | Leadership is fixed overview plus drill-down; Token mix semantics differ from macOS. |
| Month value | Local estimate surface | Not official quota/bill and not strict macOS Wool equivalence. |
| Tasks / Skills | `variable panel + not implemented` for strict comparison | The current image proves the shared tab bar, not panel internals; this label is comparison evidence only, not a global product/IPC/source conclusion. |
| Usage / Projects | Existing lower-area surfaces | The current image proves their shared tab bar only, not internal panel content. |

There is no active Claude provider or selector in this Dashboard. The refactor does not introduce a fake quota, a remote data source, or a UI inference from raw body content.

## Validation record

| Check | Result |
| --- | --- |
| `npm run build` | pass |
| `cargo test --workspace` | pass: 35 core + 7 Tauri tests |
| `cargo tauri build --no-bundle` | pass; release EXE built 2026-07-28 04:23:36 Asia/Shanghai |
| `git diff --check` | pass |
