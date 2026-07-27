# CODEX Dashboard Snapshot Refactor Implementation Plan

- Status: completed for the Codex-only Windows Dashboard contract.
- Date: 2026-07-28
- Companion: [`CODEX_DASHBOARD_SNAPSHOT_REFACTOR_DESIGN.md`](CODEX_DASHBOARD_SNAPSHOT_REFACTOR_DESIGN.md)

## Completed delivery sequence

| Step | Implemented result | Principal integration points |
| --- | --- | --- |
| 1. Snapshot model | Added `CodexDashboardSnapshot` and `CodexLeadershipSignal`, while preserving `RuntimeUsageSnapshot` as the nested Codex runtime contract. | `windows/crates/codexu-core/src/models/runtime.rs` |
| 2. Codex provider | Added one local `CodexDashboardProvider` that reads state metadata and transcript summaries, then composes usage and leadership branches. | `windows/crates/codexu-core/src/readers/codex_dashboard.rs` |
| 3. Leadership branch | Kept leadership calculation separate from the usage response, with interval evidence, non-stub model filtering, coverage/active-day gating, and maturity protection. | `windows/crates/codexu-core/src/readers/codex_transcript.rs`, `windows/crates/codexu-core/src/readers/leadership.rs` |
| 4. State and IPC | AppState caches `CodexDashboardSnapshot` under source-key/generation protection and serializes refreshes. Existing command names now return the snapshot shape. | `windows/apps/codexu-tauri/src-tauri/src/app_state.rs`, `windows/apps/codexu-tauri/src-tauri/src/commands/usage.rs` |
| 5. Web migration | Web types and `useUsage()` consume the snapshot; Dashboard consumers read nested local data and the independent leadership signal. | `windows/apps/codexu-tauri/web/src/types/models.ts`, `windows/apps/codexu-tauri/web/src/hooks/useUsage.ts`, `windows/apps/codexu-tauri/web/src/windows/Dashboard.tsx` |
| 6. Native acceptance | Built the release app and accepted only the current default and Leadership HWND screenshots. | `docs/windows-port/reports/assets/codex-dashboard-snapshot-*-native.png` |

## Delivery rules satisfied

1. **Codex-only:** the provider is the sole enabled Dashboard source. No Claude reader branch or selector is activated in the app UI.
2. **No fake quotas:** the runtime identifies itself as local-only and keeps official quota fields unavailable rather than filling estimates into quota fields.
3. **Independent leadership:** score/title are not inferred from local token totals. The signal is populated from the leadership report and remains null/pending when the evidence gate does not produce a score.
4. **Source-safe state:** AppState refreshes use a source key, generation check, and single-flight lock. Provider warnings do not leak state paths or SQLite details to web consumers.
5. **Nested local data:** local usage stays under `snapshot.codex.snapshot.local`; the web layer does not consume a top-level `LocalUsage` response.

## Acceptance evidence

The accepted native capture method is HWND-specific `PrintWindow`, not Computer Use. Both current images were captured at `1462x1196` physical pixels / DPI 144, approximately `975x797 CSS px`.

| Surface | Valid evidence | Acceptance fact |
| --- | --- | --- |
| Default Dashboard | [codex-dashboard-snapshot-default-native.png](../../reports/assets/codex-dashboard-snapshot-default-native.png) | Three global tabs, complete L1-L7 rail, and a non-duplicated Token mix totaling `3,500,122,541` (`1,784,569,471` + `1,706,410,112` + `9,142,958`) with no raw body content. |
| AI Leadership | [codex-dashboard-snapshot-leadership-native.png](../../reports/assets/codex-dashboard-snapshot-leadership-native.png) | Identity, evidence-gated score, rail, and metrics are visible in the detail hierarchy. |

No fresh final scrolled lower-tabs capture was accepted. It remains an evidence gap; no prior lower-panel image is relabelled as proof of the final snapshot architecture or current navigation.

## Final validation

| Check | Result |
| --- | --- |
| `npm run build` | pass |
| `cargo test --workspace` | pass: 35 core + 7 Tauri tests |
| `cargo tauri build --no-bundle` | pass; release EXE built 2026-07-28 04:23:36 Asia/Shanghai |
| `git diff --check` | pass |

## Deferred / out of scope

- A Claude provider or runtime-selection UI.
- Official account quota/rate-limit data or any synthetic quota replacement.
- A new accepted lower-tabs screenshot until it is captured from the final release state.
- Any claim that local Month estimate is a strict macOS Wool equivalent.
