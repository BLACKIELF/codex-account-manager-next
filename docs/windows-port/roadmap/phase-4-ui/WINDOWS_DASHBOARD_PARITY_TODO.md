# Windows Dashboard Parity TODO and Resolution

> Historical dashboard-panel TODO records remain superseded by the implemented 2026-07-28 Codex snapshot refactor. This document preserves their scope boundary, not stale screenshot or validation claims.

## Historical TODO context (2026-07-27)

The following items were the pre-refactor backlog. Their original states must be read as historical planning states, not as the current implementation verdict.

| Historical TODO | Original intent | Historical data/acceptance boundary |
| --- | --- | --- |
| TODO-01 | Recompose Dashboard as fixed overview plus Tasks / Usage / Projects / Skills lower area, with Leadership separate. | Reuse the existing frontend contract; do not change `useUsage()` data sources. |
| TODO-02 | Reuse Usage and Projects in lower slots rather than recreating their cards. | Do not replace chart/statistic meaning or add calculated fields. |
| TODO-03 | Establish a truthful Today/Tasks boundary. | Do not infer Tasks from Threads or change thread parsing. |
| TODO-04 | Establish a truthful Skills boundary. | Do not invent typed Skills values or relabel Tool usage as Skills. |
| TODO-05 | Decide whether Month progress could be compared with macOS Wool. | Do not label a local estimate as an official rate limit or quota. |
| TODO-06 | Update native visual evidence only after a verified release build. | Do not use an old screenshot as proof of a new UI state. |
| TODO-07 | Keep documentation, implementation, and branch changes reviewable. | Do not mix unrelated changes or treat planning as completion. |

The implemented snapshot refactor resolves the top-level contract and default/Leadership evidence below. It does not convert the historical lower-panel images into final proof.

## Completed scope

| Item | Current resolution |
| --- | --- |
| Dashboard data contract | Complete: `CodexDashboardSnapshot` is the Tauri response, nesting `RuntimeUsageSnapshot` and an independent leadership signal. |
| Provider boundary | Complete: `CodexDashboardProvider` is the only enabled local provider; no Claude selector/branch is activated. |
| Usage safety | Complete: local usage is `codex.snapshot.local`; official quota remains unavailable and is not fabricated. |
| Leadership | Complete: interval-backed report/score is independent of usage and gated by dimensions, active days, coverage, maturity, and non-stub model version. |
| Global navigation | Complete: current native default evidence shows Dashboard / AI Leadership / Threads only. |
| Lower panels | Navigation evidence complete: a final lower-tabs capture proves one Tasks / Usage / Projects / Skills tab bar. It does not prove each panel's internal content. |

## Current evidence boundary

The accepted release captures use non-Computer-Use HWND `PrintWindow` at `1462x1196` physical pixels / DPI 144, approximately `975x797 CSS px`.

| Surface | Valid evidence | What it establishes |
| --- | --- | --- |
| Default Dashboard | [codex-dashboard-snapshot-default-native.png](../../reports/assets/codex-dashboard-snapshot-default-native.png) | Three global tabs, complete L1-L7 rail, and local Token mix `1,784,569,471 + 1,706,410,112 + 9,142,958 = 3,500,122,541` without raw body content. |
| AI Leadership | [codex-dashboard-snapshot-leadership-native.png](../../reports/assets/codex-dashboard-snapshot-leadership-native.png) | Leadership identity, evidence-gated score, rail, and metrics. |
| Lower Dashboard navigation | [codex-dashboard-snapshot-lower-tabs-native.png](../../reports/assets/codex-dashboard-snapshot-lower-tabs-native.png) | Readable L1-L7, local API-equivalent Month value / not official quota, and one Tasks / Usage / Projects / Skills tab bar; not panel-internal evidence. |

The lower-tabs frame was produced through pure Win32 `SendInput` PageDown plus wheel scrolling and HWND `PrintWindow` / `PW_RENDERFULLCONTENT`, without Computer Use, UIA, or Playwright. No blank/black or historical lower-panel frame is part of the accepted set.

## Cross-platform clarification

- AI Leadership is `fixed overview` correspondence; detail is a drill-down rather than a fifth lower panel.
- Windows Month value is a local estimate, not strict macOS monthly Wool evidence. Token mix semantics differ and no official quota/bill is asserted.
- Tasks and Skills are `variable panel + not implemented` in the strict macOS/Windows comparison. This only describes strict comparison evidence; it is not a global data-contract, source, IPC, or product-scope statement. Tool usage is not relabelled as Skills.

## Final validation

| Check | Result |
| --- | --- |
| `npm run build` | pass |
| `cargo test --workspace` | pass: 35 core + 7 Tauri tests |
| `cargo tauri build --no-bundle` | pass; release EXE built 2026-07-28 04:23:36 Asia/Shanghai |
| `git diff --check` | pass |

## Non-goals retained

- No Reader/IPC expansion beyond the implemented Codex snapshot contract.
- No Claude runtime/selector, fake quota, points change, or remote service.
- No strict macOS Wool or capture-time numeric parity claim.
