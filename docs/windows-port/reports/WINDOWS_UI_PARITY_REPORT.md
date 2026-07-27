# Windows UI Parity Report: Dashboard Home Alignment (Phase-4 UI)

- Report date: 2026-07-27
- Scope: Windows dashboard-home visual hierarchy parity (dashboard-home layout, token mix labeling, native evidence, and leadership detail retention) with current-source constraints.

## Conclusion

The latest native release confirms page-level dashboard-home parity for this phase.

- Default home is a native Windows layout with three top cards in sequence and no `raw Thread` / `Project` / `Tool` content.
- `7-day Token mix` is shown as local telemetry (`Input` + `Cached input` + `Output`), not an official quota rate-limit.
- Leadership detail preserves identity, score context, full L1-L7 progression, and 2x2 metrics block.
- Visual style is Windows-native light/system with Liquid Glass tone, not a macOS dark pixel clone.

## Evidence images

- `docs/windows-port/reports/assets/dashboard-home-native.png` - default Dashboard (Home tab) capture at `1446x1350`, from `windows/target/release/codexu-tauri.exe` window state/screenshot path.
- `docs/windows-port/reports/assets/dashboard-home-leadership-detail.png` - AI Leadership tab capture at `1446x1350`, from the same executable window state after selecting `AI Leadership`.
- The Leadership image predates the final score-pin coordinate correction. It remains evidence for hierarchy, L1-L7 mapping, and metrics; the corrected 84-point geometry was manually reviewed in the rebuilt release, but no replacement PNG was captured in this batch.

### Resource reuse and canonical mapping

- Reuses existing `LeadershipCommandRail` and L1-L7 badge assets.
- Canonical thresholds: `0/20/35/50/65/80/93` (L1-L7).
- Current score `84` in captures maps to **L6** (`80-92`).

### Screenshot comparison

- Reference image: `docs/screenshot-v1.2.0-ai-leadership.png` (macOS semantic reference).
- Evidence scope is split by image:
  - Home image confirms top cards and progression block start at the visible scope.
  - AI Leadership detail image confirms full L1-L7 rail and 2x2 metrics, but is not the post-fix geometry artifact.
  - Native short-scroll validation confirms progression area follows top cards in home flow.
- Retained platform difference: Windows native-light/System Liquid Glass rendering, not dark macOS pixel matching.

### Notes on image intent

- Default Dashboard shows top layout order: Leadership summary, 7-day Token mix, Today / 7-day / Lifetime summary, then the start of the progression block in Home scope.
- Leadership detail includes score title context, 2x2 metrics, and full-domain `L1-L7` rail with native badge artifacts.
- Top cards avoid quota-rhetoric and raw prompt/response/tool payload exposure.

## Aligned items

- Canonical L1-L7 mapping and threshold bands are present.
- Home captures include top cards and progression-block start; full L1-L7 command rail and 2x2 metrics are shown in AI Leadership detail image.
- Screenshot source is the same release build for both Home and AI Leadership evidence.

## Platform differences and known gaps

- Mac screenshots are reference-only (`screenshot-v1.2.0-ai-leadership.png`, `screenshot-v1.1.0-palette-gallery.png`).
- Official quota/official rate-limit is out of scope because this UI path is not backed by quota API contract.
- No-signal/no-data native empty-state artifacts were not collected in this update.
- No manual pixel-diff run was executed in this task.
- A replacement AI Leadership screenshot after the score-pin coordinate correction was not captured in this batch.

## Validation results

| Command | cwd | Exit | Result |
| --- | --- | --- | --- |
| `npm run build` | `windows/apps/codexu-tauri/web` | 0 | `vite` + `tsc` build succeeded. |
| `cargo test --workspace` | `windows` | 0 | `running 9 tests`, all passed. |
| `cargo tauri build --no-bundle` (attempt 1) | `windows/apps/codexu-tauri/src-tauri` | 1 | `failed to remove file ... codexu-tauri.exe (os error 5)` |
| `cargo tauri build --no-bundle` (retry) | `windows/apps/codexu-tauri/src-tauri` | 0 | Built at `windows\target\release\codexu-tauri.exe` after closing existing release-process lock and rerunning. |
| `node --test tests\leadership-rail-layout.test.mjs` | `windows/apps/codexu-tauri/web` | 0 | Score pin and threshold dots share the exact rail coordinate frame. |
| `cargo tauri build --no-bundle` (final) | `windows` | 0 | Rebuilt the release executable after the score-pin coordinate correction. |
| `git diff --check` | repo root | 0 | No whitespace errors reported (LF/CRLF notice may appear on future git touches). |

## Files updated

- `docs/windows-port/showcase/WINDOWS_DASHBOARD_SHOWCASE.md`
- `docs/windows-port/showcase/WINDOWS_DASHBOARD_SHOWCASE.html`
- `docs/windows-port/reports/WINDOWS_UI_PARITY_REPORT.md`
- `docs/windows-port/reports/WINDOWS_UI_PARITY_REPORT.html`

## Suggested commit message

`feat(windows-ui): compose dashboard home`
