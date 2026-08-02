# Windows Maximized Native Visual Workflow Report

**Date:** 2026-08-03

**Checkout:** `codex/skills-dashboard-wiring-merge` at `301b323a49a80019e66f8fafd3534a8eb7b2cbd0`
**Verdict:** **Passed for the maximized-only native visual workflow scope.**

## Scope and contract

The default native workflow was run from this checkout without `-SkipBuild`. It builds the release application, launches a task-owned instance against read-only local input, targets the exact application HWND, and records one maximized capture run. The committed `-Surface` option remains available for focused capture; every selected surface uses that same maximized run.

`client_sizes` and `size_runs` are retained as reserved, empty extension points. Additional client sizes are not part of the accepted contract and require later design and validation.

## Capture evidence

| Manifest field | Recorded result |
|---|---|
| Status | `complete` |
| Capture runs | `fullscreen` only |
| Screenshot total | 10 dynamic screenshots |
| Reserved size runs | Empty |
| Process cleanup | Confirmed |
| Release build | Passed as part of the default capture command |

| Surface | Maximized capture count | Coverage |
|---|---:|---|
| Overview | 1 | Overview viewport |
| Tasks | 2 | Numbered panel viewport segments |
| AI Leadership | 2 | Numbered panel viewport segments |
| Usage | 2 | Numbered panel viewport segments |
| Projects | 1 | First panel viewport only |
| Skills | 2 | Numbered panel viewport segments |

Long surfaces use numbered viewport segments and do not repeat the dashboard top in subsequent segments. Projects intentionally remains a single first-viewport capture.

## Manual native review

All 10 fresh local-only PNGs listed by the manifest were inspected. Every frame was maximized; the selected surface matched the captured surface; no horizontal clipping was observed; and every long-surface sequence reached its recorded end coverage. The Projects capture remained limited to its first viewport, as required. The review found no selected-surface mismatch or framing failure in the accepted scope.

Screenshots and their contents remain local-only. This report contains no screenshot or artifact link, local path, raw captured text, account, thread, project, process, or other identifier, or exact product metric.

## Verification record

| Verification | Result | Notes |
|---|---|---|
| Default release build and native capture | Passed | Completed with the manifest values above. |
| Native capture workflow PowerShell test | Passed | Exit code 0. |
| Active native-visual documentation PowerShell test | Passed | Exit code 0. |
| Blueprint validation | Passed | Exit code 0. |
| Rust workspace tests | Passed | MSVC workspace command exited 0. |
| Web production build | Passed with warning | Exit code 0; existing Vite chunk-size warning remained non-blocking. |
| Web contract tests | Passed | Exit code 0; 14 tests passed. |
| Pre-report repository diff check | Passed | Exit code 0. |
| Capture-process cleanup | Confirmed | Recorded task process identities were cleaned up. |

## Known limits and next steps

- This is a point-in-time review of changing local data, not a deterministic visual-regression baseline.
- It does not certify unobserved error states, themes, dialogs, system menus, or unrelated interaction paths.
- The accepted scope is one maximized exact-HWND run. Other client sizes remain deferred while their reserved manifest fields stay empty.
- Future visual changes should rerun the default capture, inspect each manifest-listed local-only image, and renew this evidence before changing the verdict.
