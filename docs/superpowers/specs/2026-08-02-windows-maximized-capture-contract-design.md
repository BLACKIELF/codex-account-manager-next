# Windows Maximized Native Capture Contract Design

## Status

Approved for implementation on 2026-08-02. Future formal Windows UI visual
tests use one maximized exact-HWND run. Additional client sizes may be designed
later, but they are not part of the current workflow contract.

## Current contract

- `Capture-NativeVisuals.ps1` launches one task-local release application,
  maximizes its main Win32 window, verifies the maximized state, and captures
  only that exact HWND.
- The default run captures Overview plus every configured Dashboard panel.
- A `-Surface` run captures only the requested Overview or panel, but still
  uses the same maximized-window path.
- Tall panels use numbered viewport sequences. Projects records only its first
  maximized panel viewport.
- Screenshot count is dynamic. No active contract promises 960×760, 720×540,
  two size runs, or 12 PNGs.

## Active sources to update

- Keep `client_sizes` in preflight and `size_runs` in the workflow manifest as
  reserved extension points for future non-fullscreen test modes. The current
  maximized-only contract requires both arrays to remain empty.
- Update `windows/README.md` so the documented acceptance command and evidence
  describe maximized exact-HWND capture and dynamic panel sequences.
- Update the Windows Blueprint schema, Mermaid fallback, narrative, and
  deterministic render artifacts from the schema. The evidence edge describes
  a manifest, logs, and dynamic maximized viewport PNGs rather than 12 PNGs.
- Keep the selected presentation diagram semantically consistent with the
  updated schema; do not leave a stale fixed-count label in the main view.

## Historical records

Do not rewrite `.planning/` or Phase 4 product-layout documents. Their
fixed-size statements record past experiments or UI design targets rather than
the future capture contract.

Create a new paired Markdown/HTML acceptance report from a fresh maximized
native run. Only after the new report is complete and its conclusions agree in
both formats, delete the old paired two-size native-workflow acceptance report.

## Compatibility and failure behavior

`client_sizes` and `size_runs` remain schema-compatible but inactive. Future
size modes must be added deliberately with their own design and tests; they
must not silently change the current fullscreen run. Existing exact executable,
local-artifact, read-only data, bounded scrolling, and process-cleanup checks
remain unchanged. An unverified or non-maximized window still fails closed.

## Verification

- Preserve assertions that `client_sizes` and `size_runs` are empty in the
  current maximized-only workflow.
- Preserve and pass the existing single-surface selection contract.
- Pass PowerShell parsing, preflight, single-surface/default native coverage,
  Blueprint schema validation/rendering, `git diff --check`, Web contracts/build,
  and Rust workspace tests in proportion to the touched files.
- Run a fresh default release build and maximized native capture, then create
  the paired replacement acceptance report before deleting the old report.
- Search active sources after the change; remaining fixed-size references must
  be limited to the explicitly preserved historical records and product-layout
  targets.
