# macOS / Windows Dashboard Feature Comparison

- Evidence date: 2026-07-28
- Comparison rule: this is a hierarchy and evidence comparison, not a pixel, pricing, or capture-time-value comparison.

## Reading the comparison

| Label | Meaning |
| --- | --- |
| `fixed overview` | A fixed hierarchy block shown before lower-panel selection. |
| `variable panel` | A lower Dashboard panel selected from the four-tab area. |
| `variable panel + not implemented` | No strict macOS/Windows one-to-one equivalent is evidenced; a Windows UI shell or retained image may be the nearest context only. |
| `partial real panel` | A live local-data panel with related, not identical, macOS semantics. |

**Evidence boundary:** `not implemented` in this comparison labels only strict cross-platform equivalence evidence. It is not a global conclusion about the Windows product area, source code, data contract, Reader, IPC, or roadmap. Separately, a blocked data field means the active Windows contract does not provide truthful source data; no value in this page asks the UI to infer it.

## 1. Structure mapping

| macOS README structure | Windows Dashboard structure |
| --- | --- |
| Fixed dashboard overview, then variable areas for Tasks, Usage, Projects, and Skills | Fixed Dashboard: Leadership identity, local 7-day Token mix, Today/7-Day/Lifetime, L1-L7 rail, and local Month value progress. Its visible global navigation is Dashboard / AI Leadership / Threads; Tasks / Usage / Projects / Skills are the sole visible Dashboard-level entry for those four areas. |
| AI Leadership detail | Dedicated `AI Leadership` drill-down from the fixed overview, not a fifth lower panel. |

Windows uses a native light/system Liquid Glass surface rather than copying the dark macOS pixels. Runtime values may differ; the comparison does not assert numeric equality.

## 2. Fixed overview

| macOS reference | Windows native evidence |
| --- | --- |
| ![macOS AI Leadership](../../screenshot-v1.2.0-ai-leadership.png) | ![Windows fixed Dashboard](../reports/assets/dashboard-lower-panels-default-native.png) |

- Tag: `fixed overview`
- Windows fixed Dashboard contains the Leadership identity, local **7-day Token mix** (`Input`, `Cached input`, `Output`), Today / 7-day / Lifetime summaries, the full L1-L7 rail, and local Month value progress.
- Compact native evidence: at about `960x758` CSS pixels, three top groups remain horizontal and the rail title, badges, bar, and labels are all visible.
- The Token mix is local telemetry, not quota, remaining allowance, rate-limit data, or a bill. It has no duplicated count and the fixed top contains no raw thread, project, or tool content.
- This is a **fixed overview** hierarchy correspondence. Windows has a local Month value estimate surface, but it is not strict one-to-one evidence for macOS monthly Wool; Token mix semantics also differ.

## 3. Variable panels in README order

### 3.1 Today / Tasks

| macOS | Windows |
| --- | --- |
| ![macOS Today](../../screenshot-v0.3.0-today.png) | ![Windows Tasks](../reports/assets/dashboard-lower-panels-tasks-native.png) |

- Tag: `variable panel` + `not implemented` for strict cross-platform comparison
- The Windows Tasks shell is retained as nearest-context evidence only. It truthfully says task state is not exposed and does **not** infer Tasks from Threads, but it is not asserted to be a strict macOS Today/Tasks equivalent.

### 3.2 Usage

| macOS | Windows |
| --- | --- |
| ![macOS Usage](../../screenshot-v0.3.0-usage.png) | ![Windows Usage](../reports/assets/dashboard-lower-panels-usage-native.png) |

- Tag: `variable panel` + `partial real panel`
- Windows shows a real local-token usage surface. It does not claim macOS official-quota semantics.

### 3.3 Projects

| macOS | Windows |
| --- | --- |
| ![macOS Projects](../../screenshot-v0.3.0-projects.png) | ![Windows Projects](../reports/assets/dashboard-lower-panels-projects-native.png) |

- Tag: `variable panel` + `partial real panel`
- Windows shows a real local project surface at the same lower-panel level; its data presentation differs by host and contract.

### 3.4 Skills

| macOS | Windows |
| --- | --- |
| ![macOS Skills](../../screenshot-v0.3.0-skills.png) | ![Windows Skills](../reports/assets/dashboard-lower-panels-skills-native.png) |

- Tag: `variable panel` + `not implemented` for strict cross-platform comparison
- The Windows Skills shell is retained as nearest-context evidence only. It truthfully says typed Skills usage is not exposed, but it is not asserted to be a strict macOS Skills equivalent. **Tool usage is not mapped or relabelled as Skills.**

## 4. Month value progress interpretation

The fixed Windows Dashboard uses existing detailed-month `estimated_cost_usd` as a **local API-equivalent estimate**, not as an official monthly quota, allowance, remaining balance, or bill. Its markers are Plus `$20`, Pro 100 `$100`, Pro 200 `$200`, and a `$46.5K` reference cap; the first `$0–200` maps to 28%, then a `log1p` tail is used. Windows therefore has a Month-value surface, but the strict macOS monthly-Wool comparison remains a gap: pricing and source semantics differ, so the estimate is not presented as a complete Wool replacement or strict dollar parity.

## 5. Evidence files and conclusion

The default Dashboard and AI Leadership images are updated native HWND `PrintWindow` captures after the visible-navigation de-duplication. The four lower-panel images are retained nearest-context images, not recaptured evidence for the new global navigation:

- [Fixed Dashboard](../reports/assets/dashboard-lower-panels-default-native.png)
- [AI Leadership](../reports/assets/dashboard-lower-panels-leadership-native.png)
- [Tasks](../reports/assets/dashboard-lower-panels-tasks-native.png)
- [Usage](../reports/assets/dashboard-lower-panels-usage-native.png)
- [Projects](../reports/assets/dashboard-lower-panels-projects-native.png)
- [Skills](../reports/assets/dashboard-lower-panels-skills-native.png)

The retained lower-panel shots show lower-panel context only. During the current re-capture the real window collapsed to the tray/minimized state, so they must not be used to prove the current three-item global navigation or strict feature equivalence. See [`WINDOWS_DASHBOARD_SHOWCASE.md`](WINDOWS_DASHBOARD_SHOWCASE.md) and [`WINDOWS_UI_PARITY_REPORT.md`](../reports/WINDOWS_UI_PARITY_REPORT.md) for capture dimensions, validation, and known limits.
