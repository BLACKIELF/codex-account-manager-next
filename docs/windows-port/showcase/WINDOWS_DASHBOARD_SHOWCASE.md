# Windows Dashboard Showcase (Phase-4 UI)

- Evidence date: 2026-07-28
- Verdict: **accepted for page-level Windows Dashboard hierarchy at the compact desktop target.**
- Evidence source: the final native release executable, `windows/target/release/codexu-tauri.exe`.

## What is aligned

The default Windows Dashboard now follows the macOS reference's information shape without claiming pixel-for-pixel or value-for-value parity.

1. **Fixed Dashboard** — Leadership identity, a local **7-day Token mix**, Today / 7-day / Lifetime summaries, the full L1-L7 rail, and local Month value progress remain in the fixed Dashboard flow.
2. **Visible navigation and four variable lower panels** — The global navigation is `Dashboard / AI Leadership / Threads`; `Usage` and `Projects` are no longer duplicated there. Tasks, Usage, Projects, and Skills are reachable from the lower tablist as their only visible Dashboard-level entry. Leadership remains the dedicated `AI Leadership` detail surface rather than a fifth lower panel.
3. **Leadership detail** — identity, score, compact facts, and the L1-L7 command rail retain the semantic hierarchy of [`screenshot-v1.2.0-ai-leadership.png`](../../screenshot-v1.2.0-ai-leadership.png). Windows keeps its light/system Liquid Glass presentation; this is not a dark macOS pixel replica.

At the compact native capture target, the three fixed top groups are horizontal and the entire L1-L7 rail (title, badges, bar, and labels) is visible. The fixed top has no raw thread, project, or tool content. Its 7-day Token mix labels `Input`, `Cached input`, and `Output` without a duplicated count.

## Native evidence

The updated default Dashboard and AI Leadership captures used a target HWND with `PrintWindow`, not Computer Use. The default DWM bounds were `1439x1136` at DPI 144: approximately `960x758` CSS pixels. The target release process was closed after capture (zero matching target processes remained). The lower four images below are retained nearest-context images because the real window collapsed to the tray/minimized state during the current re-capture.

| Surface | Native screenshot | What it proves |
| --- | --- | --- |
| Fixed Dashboard | [dashboard-lower-panels-default-native.png](../reports/assets/dashboard-lower-panels-default-native.png) | Updated current evidence: exactly three global navigation items, three horizontal top groups, local 7-day Token mix, full L1-L7 rail, and Month progress. |
| AI Leadership detail | [dashboard-lower-panels-leadership-native.png](../reports/assets/dashboard-lower-panels-leadership-native.png) | Updated current evidence: Leadership identity, score/facts, and rail hierarchy as a drill-down from fixed overview. |
| Tasks lower panel | [dashboard-lower-panels-tasks-native.png](../reports/assets/dashboard-lower-panels-tasks-native.png) | Retained nearest-context image of the Tasks shell; not current global-navigation evidence or strict macOS-equivalence evidence. |
| Usage lower panel | [dashboard-lower-panels-usage-native.png](../reports/assets/dashboard-lower-panels-usage-native.png) | Retained nearest-context image of a real local-token panel; not current global-navigation evidence. |
| Projects lower panel | [dashboard-lower-panels-projects-native.png](../reports/assets/dashboard-lower-panels-projects-native.png) | Retained nearest-context image of a real project panel; not current global-navigation evidence. |
| Skills lower panel | [dashboard-lower-panels-skills-native.png](../reports/assets/dashboard-lower-panels-skills-native.png) | Retained nearest-context image of the Skills shell; not current global-navigation evidence or strict macOS-equivalence evidence. |

The retained Tasks, Usage, Projects, and Skills images were originally captured after scrolling to the lower tablist. They provide lower-panel context only; they are not evidence for the new top navigation, first viewport, or strict cross-platform one-to-one equivalence.

## Data interpretation and retained differences

- **7-day Token mix:** local telemetry only. It is not official quota, remaining allowance, rate-limit data, or an account bill.
- **Month value progress:** the existing detailed-month `estimated_cost_usd` drives a clearly labelled local API-equivalent estimate. Milestones are Plus `$20`, Pro 100 `$100`, Pro 200 `$200`, with a `$46.5K` reference cap. The first `$0–200` accounts for 28%; the remaining span uses a `log1p` tail. This is not an official allowance, quota, or bill. It does not establish a strict one-to-one macOS monthly-Wool equivalent because pricing and source semantics differ.
- **Tasks and Skills:** their Windows UI shells exist, with no task-status model and no typed Skills-usage field exposed. In the strict macOS/Windows comparison they are labelled `variable panel + not implemented`: their retained images are nearest context, not strict equivalents. That label is only a comparison-evidence boundary, not a conclusion about product scope, source code, Reader, IPC, or roadmap. Tool usage is not relabelled as Skills.
- **Usage and Projects:** both are real, local-data panels, but are partial semantic matches because their data contracts and host UI differ from macOS.
- **Privacy:** the fixed top does not expose prompt text, response bodies, raw thread/project/tool records, paths, or tool arguments.

## Validation record

| Check | Result | Scope note |
| --- | --- | --- |
| `npm run build` in `windows/apps/codexu-tauri/web` | pass | Completed in the final validation run. |
| `cargo test --workspace` in `windows` | pass | 9 passed / 0 failed; three zero-test targets. |
| `cargo tauri build --no-bundle` in `windows/apps/codexu-tauri/src-tauri` | pass at 02:59:09 Asia/Shanghai | Produced `windows/target/release/codexu-tauri.exe`. |
| `git diff --check` at repository root | pass | No whitespace errors in the final validation run. |

Computer Use is not an acceptance method for this batch: its Node runtime failed to initialize with `os error 3`. The documented native evidence is therefore HWND-specific `PrintWindow` capture and visual review, not a substituted Computer Use pass.

## Known limits

- No official quota/rate-limit reader, cache, IPC field, thread parser, points logic, or score calculation was changed in this work.
- No no-signal/no-data screenshot was captured for this batch.
- No pixel-diff was run; visual acceptance is hierarchy and compact-viewport usability, not pixel replication.
- Runtime values visible in screenshots are capture-time local values and are not asserted to equal the macOS screenshot values.
