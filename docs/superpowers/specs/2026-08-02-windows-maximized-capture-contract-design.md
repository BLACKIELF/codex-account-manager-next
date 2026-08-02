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

- Remove the obsolete empty `client_sizes` preflight field and `size_runs`
  workflow-manifest field, together with tests that preserve those names.
- Update `windows/README.md` so the documented acceptance command and evidence
  describe maximized exact-HWND capture and dynamic panel sequences.
- Update the Windows Blueprint schema, Mermaid fallback, narrative, and
  deterministic render artifacts from the schema. The evidence edge describes
  a manifest, logs, and dynamic maximized viewport PNGs rather than 12 PNGs.
- Keep the selected presentation diagram semantically consistent with the
  updated schema; do not leave a stale fixed-count label in the main view.

## Historical records

Do not rewrite `.planning/`, the existing paired native-workflow acceptance
report, or Phase 4 product-layout documents. Their fixed-size statements record
past experiments or UI design targets rather than the future capture contract.

## Compatibility and failure behavior

No tracked consumer reads `client_sizes` or `size_runs`; removing the empty
fields is therefore the intended contract cleanup. Existing exact executable,
local-artifact, read-only data, bounded scrolling, and process-cleanup checks
remain unchanged. An unverified or non-maximized window still fails closed.

## Verification

- Add failing preflight and coverage assertions that reject the legacy fields.
- Preserve and pass the existing single-surface selection contract.
- Pass PowerShell parsing, preflight, single-surface/default native coverage,
  Blueprint schema validation/rendering, `git diff --check`, Web contracts/build,
  and Rust workspace tests in proportion to the touched files.
- Search active sources after the change; remaining fixed-size references must
  be limited to the explicitly preserved historical records and product-layout
  targets.
