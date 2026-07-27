# Windows UI Parity Report: Dashboard Home Alignment (Phase-4 UI)

- Report date: 2026-07-28
- Scope: Windows Dashboard hierarchy, lower-panel restoration, native visual evidence, and retained data-contract boundaries.
- Verdict: **accepted for page-level Dashboard hierarchy at the compact desktop target.** This is not a pixel-perfect or numeric-parity claim.

## Acceptance conclusion

- The final native default Dashboard shows three horizontal top groups: Leadership, local 7-day Token mix, and Today / 7-day / Lifetime summaries.
- `Input`, `Cached input`, and `Output` are shown once each in the fixed top's 7-day Token mix; visual inspection found no duplicated count. The fixed top contains no raw thread, project, or tool content.
- At the target compact viewport, the complete L1-L7 rail is visible: title, badges, bar, and labels are not clipped.
- AI Leadership detail preserves the information hierarchy of [`docs/screenshot-v1.2.0-ai-leadership.png`](../../screenshot-v1.2.0-ai-leadership.png): identity, score/facts, and command rail. Windows intentionally keeps light/system Liquid Glass styling rather than copying macOS pixels.
- The lower Dashboard area exposes Tasks, Usage, Projects, and Skills. Tasks and Skills are complete honest empty shells with their required data contracts still blocked; Usage and Projects are real local-data panels with partial semantic parity.

## Native evidence

All six images come from the final `windows/target/release/codexu-tauri.exe` window. Capture used `PrintWindow` against the target HWND; it was not Computer Use. The default Dashboard DWM bounds were `1439x1136` physical pixels and the remaining capture batch was `1440x1137`; DPI 144 yields approximately `960x758` CSS pixels. Both physical sizes are within one pixel of the compact target. The exact target release process was cleaned up after capture (zero matching processes remained).

| Surface | Evidence |
| --- | --- |
| Default fixed Dashboard | [dashboard-lower-panels-default-native.png](assets/dashboard-lower-panels-default-native.png) |
| AI Leadership detail | [dashboard-lower-panels-leadership-native.png](assets/dashboard-lower-panels-leadership-native.png) |
| Tasks lower panel | [dashboard-lower-panels-tasks-native.png](assets/dashboard-lower-panels-tasks-native.png) |
| Usage lower panel | [dashboard-lower-panels-usage-native.png](assets/dashboard-lower-panels-usage-native.png) |
| Projects lower panel | [dashboard-lower-panels-projects-native.png](assets/dashboard-lower-panels-projects-native.png) |
| Skills lower panel | [dashboard-lower-panels-skills-native.png](assets/dashboard-lower-panels-skills-native.png) |

The Tasks, Usage, Projects, and Skills captures were taken after scrolling to the lower tablist. They are evidence of those tab panels, not a claim that the lower panels are in the first screen.

## Parity interpretation

| Area | Windows conclusion | Boundary |
| --- | --- | --- |
| Fixed overview | Accepted hierarchy alignment | Local Token telemetry and native-light styling; not an official quota or a macOS pixel clone. |
| Leadership detail | Accepted semantic hierarchy alignment | Compared by information order only, not a pixel diff. |
| Tasks | Complete UI shell / data blocked | No exposed task-state model; Threads are not inferred as tasks. |
| Usage | Partial real panel | Real local-token facts, not macOS official-quota semantics. |
| Projects | Partial real panel | Real local project surface; host and data presentation differ. |
| Skills | Complete UI shell / data blocked | No typed Skills-usage field; Tool usage is not relabelled as Skills. |

These blocked data fields describe the active Windows contract. They are evidence boundaries, not findings of product-feature absence.

## Month value progress decision

The fixed Dashboard now uses existing detailed-month `estimated_cost_usd` as a clearly labelled **local API-equivalent estimate**. It is not an official quota, allowance, remaining balance, or bill.

- Markers: Plus `$20`, Pro 100 `$100`, Pro 200 `$200`, and `$46.5K` reference cap.
- Mapping: the first `$0–200` maps to 28%; the remaining span uses a `log1p` tail.
- macOS pricing differs. Therefore this is feature-level hierarchy parity, not strict cross-platform dollar parity.

## Scope respected

This Dashboard work did not introduce a Dashboard Reader, cache behavior, IPC field, points change, thread parsing change, or score calculation change. It stays inside the existing frontend contracts and makes missing source fields explicit rather than inventing values.

## Validation record

| Command / check | cwd | Result | Note |
| --- | --- | --- | --- |
| `npm run build` | `windows/apps/codexu-tauri/web` | pass | Final rerun succeeded. |
| `cargo test --workspace` | `windows` | pass | Final rerun: `codexu_core` 9/9; other targets and doc tests 0. |
| `cargo tauri build --no-bundle` | `windows/apps/codexu-tauri/src-tauri` | pass at 01:55:04 | Final rerun created `windows/target/release/codexu-tauri.exe`. |
| Native visual inspection | final release HWND | pass | Compact default, Leadership detail, and four lower panels inspected from the six listed captures. |
| `git diff --check` | repository root | pass | Final diff has no whitespace errors. |

Computer Use was not available for this acceptance: its Node runtime failed to initialize with `os error 3`. The result must not be read as a Computer Use pass; it is based on HWND-specific `PrintWindow` capture and visual review.

## Known limits

- Official quota/rate-limit data remains outside the current Windows contract.
- No no-signal/no-data native screenshot was captured in this batch.
- No pixel-diff was run.
- Screenshot values are local runtime values at capture time and are not asserted to match macOS screenshot values.

## Next steps

- Keep this accepted visual scope intact; any task-status or typed Skills data must start as a separately authorized contract change rather than a UI inference.
- When a no-signal/no-data state is intentionally exercised, add a new native capture batch rather than reusing this runtime-data evidence.

## Related paired documents

- [`WINDOWS_DASHBOARD_SHOWCASE.md`](../showcase/WINDOWS_DASHBOARD_SHOWCASE.md) and [`WINDOWS_DASHBOARD_SHOWCASE.html`](../showcase/WINDOWS_DASHBOARD_SHOWCASE.html)
- [`MACOS_WINDOWS_FEATURE_COMPARISON.md`](../showcase/MACOS_WINDOWS_FEATURE_COMPARISON.md) and [`MACOS_WINDOWS_FEATURE_COMPARISON.html`](../showcase/MACOS_WINDOWS_FEATURE_COMPARISON.html)
