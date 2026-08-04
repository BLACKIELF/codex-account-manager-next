# Windows Visual Capture Demo

**Date:** 2026-07-30

**Checkout:** `codex/windows-visual-capture-demo` at `c4d58f347f41d6a93a177dbd2291fc8405ac342f`

**Verdict:** Demo executed; **phase-one visual acceptance passed** for the recorded scope.

## Scope and safeguards

This was a native Windows Tauri acceptance run against real local Codex input. It did not use fixtures, Playwright, browser mocks, baselines, pixel diffs, or Computer Use. Windows Graphics Capture targeted the exact application HWND, and the real local Codex directory remained input-only.

Twelve native screenshots were created locally: Dashboard overview plus Tasks, AI Leadership, Usage, Projects, and Skills at each requested client size. They are intentionally neither embedded nor linked here, and no screenshot, log, local path, raw task text, account data, or real metric value is included in this report.

The final capture instances and their task-owned WebView2 children were confirmed exited after collection.

## Build and verification record

| Command | Result | Notes |
|---|---|---|
| `npm run build` (from `windows/apps/codexu-tauri/web`) | Passed | Vite production build completed; only the existing chunk-size warning was emitted. |
| `cargo test --workspace` (repository-default command) | Passed | Follow-up verification on 2026-07-30 used the active `stable-x86_64-pc-windows-msvc` toolchain after removing the host-ambiguous project override: 49 tests passed and 1 authenticated-Codex-CLI quota test remained explicitly ignored. |
| `cargo +stable-x86_64-pc-windows-msvc test --workspace` | Passed | Workspace tests passed; the authenticated-Codex-CLI quota case remained explicitly ignored because it needs an installed authenticated CLI. |
| `cargo +stable-x86_64-pc-windows-msvc tauri build --no-bundle` | Passed | Built the actual release executable used for capture. Non-blocking bundle-ID and frontend chunk-size warnings remained. |

## Native capture record

| Requested client area | Verified client area | Native physical frame | Captured states |
|---|---|---:|---|
| 960 x 760 | 960 x 760 | 1445 x 1187 | Dashboard overview, Tasks, AI Leadership, Usage, Projects, Skills |
| 720 x 540 | 720 x 540 | 1085 x 857 | Dashboard overview, Tasks, AI Leadership, Usage, Projects, Skills |

Physical frame dimensions differ because Windows DPI scaling includes native window chrome. The requested client areas were verified by the capture driver before each collection.

## Manual visual acceptance

| Check | Result | Finding |
|---|---|---|
| Surface coverage | Pass | The overview and every lower Dashboard tab (Tasks, AI Leadership, Usage, Projects, Skills) were captured and manually reviewed at both requested sizes. |
| Layout and hierarchy | Pass | Overview establishes a clear header, primary leadership signal, quota area, local metrics, and lower content navigation. The 720 x 540 layout reflows to a readable vertical presentation without visible horizontal clipping. |
| Card alignment | Pass | Parallel overview cards and AI Leadership dimension cards retain consistent borders, insets, and alignment at both sizes. |
| Long text | Pass | Agent usage/activity text wraps within task cards without visible horizontal overflow or card misalignment. |
| Empty and pending/error surfaces | Pass with limit | Empty task columns render an explicit no-records state. Quota remained in a pending/retry state; no terminal quota failure was induced or claimed. |
| Usage, Projects, and Skills | Pass with limit | Usage charts, Projects rows/tool summaries, and the Skills no-records state rendered from real local input. The compact Projects detail capture necessarily shows a scrolled continuation rather than the selected-tab control in the same frame. |
| Scrolling | Pass | Native scrolling reached real detail content for all six captured surfaces at both target sizes; vertical scroll indicators and content continuation were visible. |
| Agent usage content | Pass | The Tasks view displays real agent usage/activity descriptions as intended and is accepted in this demo. |
| Real-data semantics | Pass with limit | The app showed real local state. Local usage/cost values were visually labeled as estimates rather than official quota; official quota remained clearly pending rather than being represented as zero or confirmed. |

## Conclusion and follow-up

The capture workflow is demonstrated with a real Windows Tauri executable, real local input, exact native window sizing, six recorded surfaces, and manual image review at both requested sizes. **Phase-one visual acceptance passes for this scope.**

The next phase is to turn the proven local Graphics Capture workflow into a repository-supported command and runbook, while keeping screenshots and real local artifacts untracked.

## Known limits

- This is a point-in-time visual review of changing local data, not a fixture or regression baseline.
- The review covers the overview and all five lower Dashboard tabs; it does not certify themes, dialogs, interactions beyond the recorded tab/scroll states, or terminal quota outcomes.
- The capture run itself did not modify product UI, readers, scoring, caches, IPC, or data files. The later toolchain validation repair changes developer setup and CI only; this report does not claim a push.
