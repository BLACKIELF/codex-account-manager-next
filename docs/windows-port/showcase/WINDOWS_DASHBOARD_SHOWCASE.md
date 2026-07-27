# Windows Dashboard Showcase (Phase-4 UI)

- Evidence date: 2026-07-28
- Verdict: **accepted for page-level Windows Dashboard hierarchy at the compact desktop target.**
- Evidence source: the final native release executable, `windows/target/release/codexu-tauri.exe`.

## What is aligned

The default Windows Dashboard now follows the macOS reference's information shape without claiming pixel-for-pixel or value-for-value parity.

1. **Fixed Dashboard** — Leadership identity, a local **7-day Token mix**, Today / 7-day / Lifetime summaries, the full L1-L7 rail, and local Month value progress remain in the fixed Dashboard flow.
2. **Four variable lower panels** — Tasks, Usage, Projects, and Skills are reachable from the lower tablist. Leadership remains the dedicated `AI Leadership` detail surface rather than a fifth lower panel.
3. **Leadership detail** — identity, score, compact facts, and the L1-L7 command rail retain the semantic hierarchy of [`screenshot-v1.2.0-ai-leadership.png`](../../screenshot-v1.2.0-ai-leadership.png). Windows keeps its light/system Liquid Glass presentation; this is not a dark macOS pixel replica.

At the compact native capture target, the three fixed top groups are horizontal and the entire L1-L7 rail (title, badges, bar, and labels) is visible. The fixed top has no raw thread, project, or tool content. Its 7-day Token mix labels `Input`, `Cached input`, and `Output` without a duplicated count.

## Native evidence

The capture batch used a target HWND with `PrintWindow`, not Computer Use. DWM bounds were `1439x1136` for the default Dashboard and `1440x1137` for the remaining five panels at DPI 144: approximately `960x758` CSS pixels, within one physical pixel of the batch target. The target release process was closed after capture (zero matching target processes remained).

| Surface | Native screenshot | What it proves |
| --- | --- | --- |
| Fixed Dashboard | [dashboard-lower-panels-default-native.png](../reports/assets/dashboard-lower-panels-default-native.png) | Three horizontal top groups, local 7-day Token mix, no raw fixed-top content, full L1-L7 rail, and Month progress. |
| AI Leadership detail | [dashboard-lower-panels-leadership-native.png](../reports/assets/dashboard-lower-panels-leadership-native.png) | Leadership identity, score/facts, and rail hierarchy comparable by information order to the macOS reference. |
| Tasks lower panel | [dashboard-lower-panels-tasks-native.png](../reports/assets/dashboard-lower-panels-tasks-native.png) | The Tasks shell is present and truthfully says task state is not exposed; Threads are not inferred as tasks. |
| Usage lower panel | [dashboard-lower-panels-usage-native.png](../reports/assets/dashboard-lower-panels-usage-native.png) | A real local-token usage panel, intentionally partial versus macOS quota semantics. |
| Projects lower panel | [dashboard-lower-panels-projects-native.png](../reports/assets/dashboard-lower-panels-projects-native.png) | A real project panel at the matched lower-panel level, intentionally partial. |
| Skills lower panel | [dashboard-lower-panels-skills-native.png](../reports/assets/dashboard-lower-panels-skills-native.png) | The Skills shell is present and truthfully states that typed Skills usage is not exposed. Tool usage is not relabelled as Skills. |

The Tasks, Usage, Projects, and Skills images were captured after scrolling to the lower tablist. They prove the tab panels; they are not evidence that those lower panels belong in the first viewport.

## Data interpretation and retained differences

- **7-day Token mix:** local telemetry only. It is not official quota, remaining allowance, rate-limit data, or an account bill.
- **Month value progress:** the existing detailed-month `estimated_cost_usd` drives a clearly labelled local API-equivalent estimate. Milestones are Plus `$20`, Pro 100 `$100`, Pro 200 `$200`, with a `$46.5K` reference cap. The first `$0–200` accounts for 28%; the remaining span uses a `log1p` tail. This is not an official allowance, quota, or bill. macOS pricing differs, so no strict dollar parity is claimed.
- **Tasks and Skills:** their UI shells are complete. Their underlying data contracts remain blocked: no task-status model is exposed, and no typed Skills-usage field is exposed. This is an evidence boundary, not a claim that those product areas do not exist.
- **Usage and Projects:** both are real, local-data panels, but are partial semantic matches because their data contracts and host UI differ from macOS.
- **Privacy:** the fixed top does not expose prompt text, response bodies, raw thread/project/tool records, paths, or tool arguments.

## Validation record

| Check | Result | Scope note |
| --- | --- | --- |
| `npm run build` in `windows/apps/codexu-tauri/web` | pass | Final rerun completed successfully. |
| `cargo test --workspace` in `windows` | pass | Final rerun: `codexu_core` 9/9; other targets and doc tests 0. |
| `cargo tauri build --no-bundle` in `windows/apps/codexu-tauri/src-tauri` | pass at 01:55:04 | Final rerun produced `windows/target/release/codexu-tauri.exe`. |
| `git diff --check` at repository root | pass | Final documentation/implementation diff has no whitespace errors. |

Computer Use is not an acceptance method for this batch: its Node runtime failed to initialize with `os error 3`. The documented native evidence is therefore HWND-specific `PrintWindow` capture and visual review, not a substituted Computer Use pass.

## Known limits

- No official quota/rate-limit reader, cache, IPC field, thread parser, points logic, or score calculation was changed in this work.
- No no-signal/no-data screenshot was captured for this batch.
- No pixel-diff was run; visual acceptance is hierarchy and compact-viewport usability, not pixel replication.
- Runtime values visible in screenshots are capture-time local values and are not asserted to equal the macOS screenshot values.
