# Windows Dashboard Home Showcase

## What this release validates

- Native Windows Dashboard Home in final release mode.
- Native screenshots for the default home and Leadership detail views, with the Leadership image retained as pre-fix structural evidence.
- Dashboard hierarchy validation without claiming macOS pixel-level parity.
- Resource reuse is unchanged: existing `LeadershipCommandRail` and L1-L7 badge assets are retained.
- Canonical mapping thresholds are `0/20/35/50/65/80/93` (L1-L7), so score **84** is rendered as **L6**.

## Mapping of hierarchy to captured windows

1. **Top three cards on default home**
   - Leadership identity card.
   - 7-day Token mix card.
   - Today / 7-day / Lifetime summary card.
2. **Progression rail**
   - Full-width L1-L7 command rail with native badge + threshold semantics.
3. **Leadership detail**
   - Identity + score context.
   - 2x2 leadership metrics.
   - Full-domain L1-L7 rail + compact marker.

## Screenshot comparison and evidence scope

- Reference: `docs/screenshot-v1.2.0-ai-leadership.png` (macOS semantic reference).
- This release aligns by evidence scope:
  - Home capture proves top three cards and the start of the progression area.
  - Full L1-L7 rail and 2x2 metrics are visible in AI Leadership detail capture, but that image predates the final score-pin coordinate correction.
  - Native short-scroll check confirms the progression area follows the top cards in the same release-home flow.
- The corrected 84-point geometry was manually reviewed in the rebuilt release. This batch does not include a replacement AI Leadership PNG, so the existing image is not evidence for post-fix point-to-fill alignment.
- Retained implementation difference from reference is the platform style:
  - Windows native-light / Liquid Glass rendering
  - Not a dark macOS pixel clone.

## Token model and naming

- The Home center value is a **local 7-day Token mix** (`Input`, `Cached input`, `Output`).
- The UI does not expose official quota/remaining allowance because the current Windows data path has no official quota contract in this scope.
- No raw prompt / response / tool-arguments / project / thread content is shown on default home.

## Platform interpretation

- Windows stays native-light and Liquid Glass in tone.
- macOS screenshots remain semantic references only.
- This is intentional product-local implementation, not a dark promotional mirror.

## Evidence

- `docs/windows-port/reports/assets/dashboard-home-native.png`
- `docs/windows-port/reports/assets/dashboard-home-leadership-detail.png`

The Leadership detail image is retained for hierarchy, mapping, and metrics only; it predates the final score-pin coordinate correction.

## Raw verification

- `npm run build` (`windows/apps/codexu-tauri/web`) -> exit `0`
- `cargo test --workspace` (`windows`) -> exit `0`, result `running 9 tests`, `9 passed`
- `cargo tauri build --no-bundle` (`windows/apps/codexu-tauri/src-tauri`) -> attempt 1 exit `1` (`os error 5`), then exact-release retry exit `0`
- Screenshots are from that retry-built `windows/target/release/codexu-tauri.exe` output
- `node --test tests\leadership-rail-layout.test.mjs` (`windows/apps/codexu-tauri/web`) -> exit `0`; score pin and threshold dots share the exact rail coordinate frame
- `cargo tauri build --no-bundle` (`windows`) -> final exit `0` after the score-pin coordinate correction
- `git diff --check` -> exit `0` (no whitespace errors; LF/CRLF conversion notice only if file rewritten by git later)

## Known gaps

- Official quota coverage remains pending until quota backend is intentionally integrated.
- Native no-signal empty-state artifacts were not collected in this pass.
- No manual pixel-diff was run for this update.
- A replacement AI Leadership screenshot after the score-pin coordinate correction was not captured in this batch.

## Aligned items (explicit)

- Canonical L1-L7 threshold mapping and leadership command rail semantics are present in the evidence capture; post-fix point-to-fill alignment is validated by the regression test and manual release review, not by the retained PNG.
- Identity/score context and 2x2 metric block are present in AI Leadership tab capture.
- Default home uses `7-day Token mix` local telemetry naming and does not expose raw usage context.
