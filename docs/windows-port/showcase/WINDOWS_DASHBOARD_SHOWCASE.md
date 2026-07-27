# Windows Dashboard Showcase — Codex Snapshot

- Evidence date: 2026-07-28
- Verdict: accepted for the implemented Codex-only snapshot hierarchy and compact native Dashboard surface.

## What is implemented

The Dashboard consumes one local `CodexDashboardSnapshot`: a nested Codex runtime snapshot plus an independent leadership signal. The visible global tabs are `Dashboard / AI Leadership / Threads`; the Dashboard is not a Claude selector and does not claim an enabled Claude provider.

- Local usage stays at `snapshot.codex.snapshot.local` and remains local telemetry.
- The runtime is local-only; official quota, allowance, remaining-balance, and billing values are not fabricated.
- Leadership has its own evidence-gated report/score branch. A null score remains insufficient/pending rather than becoming a UI-derived rank.
- The fixed overview contains the three-part Token mix, Today / 7-day / Lifetime summaries, and the full L1-L7 rail. The Month value is a local estimate, not strict macOS Wool parity.

## Accepted native evidence

Capture used HWND-specific `PrintWindow`, not Computer Use. The three valid final images are `1462x1196` physical pixels at DPI 144, approximately `975x797 CSS px`. The lower-tabs frame was reached through pure Win32 `SendInput` PageDown plus wheel scrolling, then captured with `PW_RENDERFULLCONTENT`; it did not use Computer Use, UIA, or Playwright.

| Surface | Current evidence | What it proves |
| --- | --- | --- |
| Default Dashboard | [codex-dashboard-snapshot-default-native.png](../reports/assets/codex-dashboard-snapshot-default-native.png) | Exactly three global tabs; full L1-L7 rail; Token mix `1,784,569,471 + 1,706,410,112 + 9,142,958 = 3,500,122,541`; no raw body content. |
| AI Leadership detail | [codex-dashboard-snapshot-leadership-native.png](../reports/assets/codex-dashboard-snapshot-leadership-native.png) | Identity, evidence-gated score, rail, and metrics in the drill-down hierarchy. |
| Lower Dashboard navigation | [codex-dashboard-snapshot-lower-tabs-native.png](../reports/assets/codex-dashboard-snapshot-lower-tabs-native.png) | Readable L1-L7, Month value explicitly labelled local API-equivalent estimate / not official quota, and exactly one Tasks / Usage / Projects / Skills tab bar. |

The accepted lower-tabs image proves the current navigation hierarchy and its single tab bar only. It does not prove each variable panel's internal content or strict one-to-one macOS feature equivalence.

## Validation

| Check | Result |
| --- | --- |
| `npm run build` | pass |
| `cargo test --workspace` | pass: 35 core + 7 Tauri tests |
| `cargo tauri build --no-bundle` | pass; release EXE built 2026-07-28 04:23:36 Asia/Shanghai |
| `git diff --check` | pass |

## Retained limits

- No active Claude runtime/provider or runtime selector.
- No official quota reader or fake quota display.
- No prompt/response body, raw tool arguments, credentials, or paths in the fixed overview.
- No strict cross-platform dollar/Wool claim for the local Month estimate.
