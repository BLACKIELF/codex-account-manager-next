# Windows Native Visual Workflow Report

**Date:** 2026-08-01

**Checkout:** `codex/windows-visual-capture-demo` at `934d9e395efabab2694ba5cce97c83db0bae87c9`

**Verdict:** **Phase-two native visual workflow acceptance and the maximized six-surface follow-up passed for the recorded scope.**

## Outcome

The proven Windows Graphics Capture prototype is now a repository-supported PowerShell workflow with a matching runbook and preflight contract test. The default command builds the real Windows Tauri release application, launches task-owned instances against read-only real local Codex input, verifies both requested client sizes under the active DPI, captures the Dashboard overview and all five lower tabs by exact application HWND, and cleans up only the recorded task process identities.

The workflow does not use Computer Use, Playwright, fixtures, browser mocks, baselines, or pixel diffs. The maximized follow-up changed only the Tasks card presentation: long activity titles now keep their complete visible text, reserve a stable minimum title area, and no longer compete horizontally with the state label. It did not modify data readers, scoring, caching, IPC, or the source data.

## Formal command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\Capture-NativeVisuals.ps1
```

The accepted run used this default command without `-SkipBuild`.

## Workflow contract

| Area | Accepted behavior |
|---|---|
| Application | Builds and launches the actual Windows Tauri release application from the current checkout. |
| Input | Uses real local Codex state as read-only input; task runtime and WebView2 storage remain isolated. |
| Window sizes | Sets and rereads 960×760 and 720×540 logical client areas, with DPI-aware physical sizing. |
| Coverage | Captures Overview, Tasks, AI Leadership, Usage, Projects, and Skills at both sizes: 12 native screenshots. |
| Targeting | Selects real tabs through UI Automation and captures the exact main HWND through Windows Graphics Capture. |
| Framing | Resets horizontal scroll, waits for WebView2 smooth scrolling to settle, and keeps the selected tab with inspectable content; compact Projects includes multiple list rows in the same frame. |
| Process safety | Refuses to take over an existing exact release executable and cleans only recorded app/WebView2 identities in success, failure, or interruption paths. |
| Artifact boundary | Keeps screenshots, logs, runtime data, process records, and review derivatives in the Git-ignored local-artifact boundary. They are not embedded or linked here. |

## Verification record

| Verification | Result | Evidence summary |
|---|---|---|
| Default native capture entry | Passed | Release build completed; 12 screenshots were produced for two sizes and six surfaces; final cleanup was confirmed. |
| PowerShell preflight contract | Passed | Capture engine, exact-HWND targeting, build command, SDK/compiler prerequisites, surface/size coverage, DPI scaling, and local output boundary were checked. |
| PowerShell syntax | Passed | The formal entry and its contract test parsed without errors. |
| Web production build | Passed | Vite production build completed; the existing non-blocking chunk-size warning remained. |
| Web contract tests | Passed | 7 tests passed, including the Tasks no-clamp and independent-footer layout contract. |
| Rust workspace tests | Passed with one expected ignore | 49 tests passed; the authenticated local-CLI integration case remained explicitly ignored. |
| Whitespace validation | Passed | `git diff --check` completed without errors after report generation. |

## Manual review of the 12 screenshots

| Surface | 960×760 | 720×540 |
|---|---|---|
| Overview | Passed: header, status, leadership/quota/summary cards, progress area, navigation, and content hierarchy are aligned and readable. | Passed: compact vertical hierarchy remains readable with no horizontal scrollbar or clipping. |
| Tasks | Passed: selected tab, two lists, multiple cards, status labels, timestamps, and long activity text are visible without overlap. | Passed: selected tab, list heading, multiple cards, and wrapped long text remain in the same frame. |
| AI Leadership | Passed: selected tab, period/evidence labels, level ring and track, and metric cards are aligned. | Passed: selected tab, title, level label, and level-ring content remain identifiable in the compact frame. |
| Usage | Passed: selected tab, four summary cards, estimate semantics, and chart heading are visible and aligned. | Passed: selected tab and the compact two-column card grid remain readable without collision. |
| Projects | Passed: selected tab, list heading, multiple rows, relative bars, and the right-side value column are aligned. | Passed: selected tab, heading, count, and multiple complete project rows share the same frame; this resolves the phase-one framing limitation. |
| Skills | Passed: selected tab and the complete real empty state share the frame with stable horizontal alignment. | Passed: selected tab, empty-state icon, title, and explanation remain complete and centered. |

Across the set, layout hierarchy, parallel-card alignment, long-text wrapping, list/chart presentation, scrolling, compact framing, and distinctions between official, recorded, estimated, waiting, and unavailable data were manually reviewed. Tasks content was treated as expected agent usage/activity product content.

## Maximized six-surface follow-up

After the formal workflow acceptance, a separate native follow-up captured the same six surfaces from one maximized release-app instance. The first Tasks attempt was rejected because a two-line clamp produced visible ellipsis. The accepted implementation keeps a minimum title height but allows activity titles to wrap to their complete visible length, while moving the state label into a separate card footer. The four state columns and all data semantics remain unchanged.

| Surface | Maximized manual review |
|---|---|
| Overview | Passed: the default Tasks tab, overview cards, navigation, and content hierarchy remain aligned. |
| Tasks | Passed: four state columns share the top line; long activity titles wrap without a UI clamp, truncation, or ellipsis; state labels occupy separate footers. |
| AI Leadership | Passed: selected tab, title, badge, level track, score, and metric cards remain aligned. |
| Usage | Passed: selected tab, four summary cards, charts, labels, and axes remain readable and aligned. |
| Projects | Passed: selected tab and multiple project/tool rows share the frame; names, values, and relative bars remain aligned. |
| Skills | Passed: selected tab and the real empty state remain complete, centered, and clearly distinguished from an error. |

All six images were produced by exact-HWND Windows Graphics Capture from the same release build and read-only local snapshot. They remain local-only and are neither embedded nor linked by this report.

## Process cleanup

Both formal size runs and the maximized follow-up recorded the task application and its WebView2 descendants before cleanup. The accepted maximized run reported no remaining matching process identity and no identity mismatch. A post-run read-only check found no live recorded identity, no matching isolated runtime command line, and no running exact release application instance.

## Known limits

- This is a point-in-time review of changing real local data, not a deterministic fixture or visual regression baseline.
- The accepted snapshot covered normal content, a waiting quota state, and a Skills empty state. No terminal product error state appeared, so terminal error visuals are not certified.
- The review covers the Dashboard overview and five lower tabs at the two requested sizes plus one maximized follow-up. Overview and Tasks intentionally show the same default Tasks selection. It does not certify theme combinations, dialogs, system menus, or unrelated interaction paths.
- Windows Graphics Capture requires working D3D11, Windows SDK metadata, a compatible .NET C# compiler, UI Automation, WebView2, and the MSVC Rust toolchain.

No screenshot, log, local artifact location, raw task text, account detail, process identifier, or real product metric is included in this report.
