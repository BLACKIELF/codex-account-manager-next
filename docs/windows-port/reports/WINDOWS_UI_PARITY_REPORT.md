# Windows UI Parity Report: Dashboard Home Alignment (Phase-4 UI)

- Report date: 2026-07-28
- Scope: Windows Dashboard hierarchy, lower-panel restoration, native visual evidence, and retained data-contract boundaries.
- Verdict: **accepted for page-level Dashboard hierarchy at the compact desktop target.** This is not a pixel-perfect or numeric-parity claim.

## Acceptance conclusion

- The updated native default Dashboard shows exactly three global navigation items — Dashboard, AI Leadership, and Threads — plus three horizontal top groups: Leadership, local 7-day Token mix, and Today / 7-day / Lifetime summaries. Usage and Projects no longer duplicate the lower Dashboard tabs in visible global navigation.
- `Input`, `Cached input`, and `Output` are shown once each in the fixed top's 7-day Token mix; visual inspection found no duplicated count. The fixed top contains no raw thread, project, or tool content.
- At the target compact viewport, the complete L1-L7 rail is visible: title, badges, bar, and labels are not clipped.
- AI Leadership detail preserves the information hierarchy of [`docs/screenshot-v1.2.0-ai-leadership.png`](../../screenshot-v1.2.0-ai-leadership.png): identity, score/facts, and command rail. Windows intentionally keeps light/system Liquid Glass styling rather than copying macOS pixels.
- The lower Dashboard area exposes the single visible Tasks / Usage / Projects / Skills entry set. Its Windows Tasks and Skills shells remain honest about missing source data; Usage and Projects are real local-data panels with partial semantic parity.

## Native evidence

The updated default Dashboard and AI Leadership images come from the final `windows/target/release/codexu-tauri.exe` window. Capture used `PrintWindow` against the target HWND; it was not Computer Use. The updated default Dashboard DWM bounds were `1439x1136` physical pixels; DPI 144 yields approximately `960x758` CSS pixels. The exact target release process was cleaned up after capture (zero matching processes remained). The lower four images are retained nearest-context images because the real window collapsed to the tray/minimized state during the current re-capture.

| Surface | Evidence |
| --- | --- |
| Default fixed Dashboard | [dashboard-lower-panels-default-native.png](assets/dashboard-lower-panels-default-native.png) |
| AI Leadership detail | [dashboard-lower-panels-leadership-native.png](assets/dashboard-lower-panels-leadership-native.png) |
| Tasks lower panel | [dashboard-lower-panels-tasks-native.png](assets/dashboard-lower-panels-tasks-native.png) |
| Usage lower panel | [dashboard-lower-panels-usage-native.png](assets/dashboard-lower-panels-usage-native.png) |
| Projects lower panel | [dashboard-lower-panels-projects-native.png](assets/dashboard-lower-panels-projects-native.png) |
| Skills lower panel | [dashboard-lower-panels-skills-native.png](assets/dashboard-lower-panels-skills-native.png) |

The lower Tasks, Usage, Projects, and Skills captures were originally taken after scrolling to the lower tablist. They are retained lower-panel context, not evidence of the current three-item global navigation, first screen, or strict cross-platform equivalence.

## Parity interpretation

| Area | Windows conclusion | Boundary |
| --- | --- | --- |
| Fixed overview / AI Leadership | Accepted hierarchy alignment | Leadership is a fixed overview correspondence; detail is a drill-down. Local Token telemetry differs from macOS Token mix, and Month value estimate is not strict macOS Wool evidence. |
| Tasks | `variable panel + not implemented` for strict comparison | Windows shell is retained nearest context; no exposed task-state model and Threads are not inferred as tasks. |
| Usage | Partial real panel | Real local-token facts, not macOS official-quota semantics. |
| Projects | Partial real panel | Real local project surface; host and data presentation differ. |
| Skills | `variable panel + not implemented` for strict comparison | Windows shell is retained nearest context; no typed Skills-usage field; Tool usage is not relabelled as Skills. |

The strict-comparison `not implemented` label describes only one-to-one macOS/Windows evidence; it is not a finding about global product scope, source code, Reader, IPC, or roadmap. Separately, blocked data fields describe the active Windows contract and are not findings of product-feature absence.

## Month value progress decision

The fixed Dashboard uses existing detailed-month `estimated_cost_usd` as a clearly labelled **local API-equivalent estimate**. It is not an official quota, allowance, remaining balance, or bill, and it is not a complete or strict one-to-one macOS monthly-Wool replacement.

- Markers: Plus `$20`, Pro 100 `$100`, Pro 200 `$200`, and `$46.5K` reference cap.
- Mapping: the first `$0–200` maps to 28%; the remaining span uses a `log1p` tail.
- macOS pricing and source semantics differ. Therefore the Windows Month-value surface leaves a strict macOS-Wool comparison gap; it is feature-level hierarchy parity, not strict cross-platform dollar parity.

## Scope respected

This Dashboard work did not introduce a Dashboard Reader, cache behavior, IPC field, points change, thread parsing change, or score calculation change. It stays inside the existing frontend contracts and makes missing source fields explicit rather than inventing values.

## Validation record

| Command / check | cwd | Result | Note |
| --- | --- | --- | --- |
| `npm run build` | `windows/apps/codexu-tauri/web` | pass | Completed in the final validation run. |
| `cargo test --workspace` | `windows` | pass | 9 passed / 0 failed; three zero-test targets. |
| `cargo tauri build --no-bundle` | `windows/apps/codexu-tauri/src-tauri` | pass at 02:59:09 Asia/Shanghai | Produced `windows/target/release/codexu-tauri.exe`. |
| Native visual inspection | final release HWND | pass with evidence split | Updated compact default and Leadership detail were inspected after global-nav de-duplication; lower four remain retained nearest-context images, not current-nav proof. |
| `git diff --check` | repository root | pass | No whitespace errors in the final validation run. |

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
