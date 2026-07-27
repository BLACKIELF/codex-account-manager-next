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

Capture used HWND-specific `PrintWindow`, not Computer Use. Both valid final images are `1462x1196` physical pixels at DPI 144, approximately `975x797 CSS px`.

| Surface | Current evidence | What it proves |
| --- | --- | --- |
| Default Dashboard | [codex-dashboard-snapshot-default-native.png](../reports/assets/codex-dashboard-snapshot-default-native.png) | Exactly three global tabs; full L1-L7 rail; Token mix `1,784,569,471 + 1,706,410,112 + 9,142,958 = 3,500,122,541`; no raw body content. |
| AI Leadership detail | [codex-dashboard-snapshot-leadership-native.png](../reports/assets/codex-dashboard-snapshot-leadership-native.png) | Identity, evidence-gated score, rail, and metrics in the drill-down hierarchy. |

No fresh final scrolled lower-tabs image was accepted. The absence is recorded as an evidence gap; no earlier lower-panel capture is reused to prove final navigation or snapshot behavior.

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
