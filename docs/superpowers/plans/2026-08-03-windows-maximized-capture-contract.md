# Windows Maximized Native Capture Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the future Windows native visual-test contract consistently maximized-only across runtime metadata, README, Blueprint, and acceptance reporting while retaining empty extension fields for possible later size modes.

**Architecture:** `Capture-NativeVisuals.ps1` remains the executable source of runtime behavior: one maximized exact-HWND run, optionally filtered by `-Surface`, with dynamic panel segments. Active documentation and Blueprint artifacts describe that behavior; a fresh paired acceptance report replaces the obsolete two-size report only after real native evidence passes.

**Tech Stack:** Windows PowerShell 5.1, Windows Graphics Capture, UI Automation, YAML, Mermaid, project-local Python Blueprint renderer, static Markdown/HTML reports.

## Global Constraints

- Future formal Windows UI visual tests use one maximized exact-HWND run.
- `client_sizes` and `size_runs` remain present and empty as reserved extension points; other sizes require a later design and tests.
- Preserve the committed `-Surface` selection behavior; every selected surface still uses the maximized run.
- Keep `.planning/` and Phase 4 product-layout documents unchanged as historical/design evidence.
- Create matching Markdown and HTML acceptance reports before deleting the old paired two-size report.
- Never embed or link local screenshots, logs, paths, raw task text, account details, process IDs, or real product metrics in reports or commits.
- Preserve local-only artifacts, exact executable ownership, read-only input, and fail-closed cleanup behavior.

---

### Task 1: Lock and document the active maximized-only contract

**Files:**
- Create: `windows/scripts/tests/Test-NativeVisualDocumentation.ps1`
- Modify: `windows/README.md`
- Modify: `docs/windows-port/blueprint/schema.yaml`
- Modify: `docs/windows-port/blueprint/diagram.mmd`
- Modify: `docs/windows-port/blueprint/BLUEPRINT.md`

**Interfaces:**
- Consumes: preflight `capture_runs = ['fullscreen']`, `client_sizes = []`, workflow `size_runs = []`, and committed `-Surface` behavior.
- Produces: a repository test that rejects stale active documentation plus schema labels consumed by the Blueprint renderer.

- [ ] **Step 1: Write the failing documentation-contract test**

Create a PowerShell test that reads only active documentation sources and rejects the obsolete contract:

```powershell
$activeFiles = @(
  'windows\README.md',
  'docs\windows-port\blueprint\schema.yaml',
  'docs\windows-port\blueprint\diagram.mmd',
  'docs\windows-port\blueprint\BLUEPRINT.md'
)
$obsoletePatterns = @(
  '960×760',
  '720×540',
  '12 PNGs',
  'Native Screenshot Demo'
)
```

Resolve each path from the repository root, collect every matching
`file:pattern`, and throw when the collection is non-empty. Also assert that
`windows/README.md` contains `最大化`, `exact HWND`, and a `-Surface Skills`
example, and that `schema.yaml` contains `Maximized Capture Workflow` and
`dynamic PNGs`.

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualDocumentation.ps1
```

Expected: FAIL listing the current README and Blueprint occurrences of the two
fixed sizes, `12 PNGs`, and `Native Screenshot Demo`.

- [ ] **Step 3: Update README and Blueprint semantic sources**

Update `windows/README.md` to state:

- the default command builds and captures one maximized exact-HWND run;
- Overview and every Dashboard surface are captured with dynamic numbered
  panel segments;
- Projects captures one maximized first viewport;
- `-Surface Skills` is the focused-run example;
- additional client sizes are not part of the current contract.

Update Blueprint sources with these exact semantic replacements:

```text
Native Screenshot Demo -> Maximized Capture Workflow
manifest · logs · 12 PNGs -> manifest · logs · dynamic PNGs
produces manifest + 12 PNGs -> produces maximized viewport PNGs
```

In `BLUEPRINT.md`, explain that `client_sizes` and `size_runs` are reserved and
empty, while current evidence is a single maximized run with a dynamic count.

- [ ] **Step 4: Run the documentation contract and existing preflight test**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualDocumentation.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualCaptureWorkflow.ps1
```

Expected: both PASS. The preflight test continues to prove `client_sizes` is
present and empty and the focused `Skills` preflight selects no extra surface.

- [ ] **Step 5: Commit the active contract sources**

```powershell
git add -- windows/README.md windows/scripts/tests/Test-NativeVisualDocumentation.ps1 docs/windows-port/blueprint/schema.yaml docs/windows-port/blueprint/diagram.mmd docs/windows-port/blueprint/BLUEPRINT.md
git commit -m "docs(windows): make maximized capture the active contract"
```

### Task 2: Regenerate and review every Blueprint presentation artifact

**Files:**
- Modify: `docs/windows-port/blueprint/diagram.svg`
- Modify: `docs/windows-port/blueprint/diagram.html`
- Modify: `docs/windows-port/blueprint/diagram.render.png`
- Modify: `docs/windows-port/blueprint/diagram.generated.png`
- Modify: `docs/windows-port/blueprint/diagram.png`

**Interfaces:**
- Consumes: updated `schema.yaml`, `diagram.mmd`, and the existing reviewed Blueprint composition.
- Produces: deterministic and selected presentation views with no fixed-count or demo labels.

- [ ] **Step 1: Regenerate deterministic SVG and HTML from schema**

Run:

```powershell
uv run --with pyyaml python .\docs\windows-port\blueprint\render.py --schema .\docs\windows-port\blueprint\schema.yaml --out-dir .\docs\windows-port\blueprint
```

Expected: `diagram.svg` and `diagram.html` are rewritten from the updated
schema and contain `Maximized Capture Workflow` plus `dynamic PNGs` semantics.

- [ ] **Step 2: Regenerate the deterministic raster candidate**

Run the existing Windows browser fallback:

```powershell
python C:\Users\ADMIN\.cc-switch\skills\blueprint\scripts\html_to_png.py .\docs\windows-port\blueprint\diagram.html .\docs\windows-port\blueprint\diagram.render.png --width 1800 --height 1400
```

Expected: `diagram.render.png` is non-empty and visually matches the SVG/HTML.

- [ ] **Step 3: Update the reviewed generated presentation candidate**

Use the image-generation edit workflow against the existing
`diagram.generated.png`, preserving geometry, colors, and all other labels.
Change only:

```text
Native Screenshot Demo -> Maximized Capture Workflow
manifest + 12 PNGs · local only -> manifest + dynamic PNGs · local only
```

Save the reviewed edit as `diagram.generated.png`. Reject and retry the edit if
any unrelated label, arrow, node, or boundary changes.

- [ ] **Step 4: Select and verify the human-facing Blueprint image**

After visual review, copy the semantically correct reviewed generated candidate
byte-for-byte to `diagram.png`. Verify both images show the exact new labels and
retain the prior composition. If a faithful generated edit cannot be obtained,
select `diagram.render.png` instead and update `BLUEPRINT.md` to record that
deterministic fallback honestly.

- [ ] **Step 5: Validate Blueprint semantics and geometry**

Run:

```powershell
uv run --with pyyaml python C:\Users\ADMIN\.cc-switch\skills\blueprint\scripts\validate_blueprint.py --schema .\docs\windows-port\blueprint\schema.yaml --artifacts-dir .\docs\windows-port\blueprint
python C:\Users\ADMIN\.cc-switch\skills\blueprint\scripts\check_svg_geometry.py .\docs\windows-port\blueprint\diagram.svg --json-out .\docs\windows-port\blueprint\geometry.json --overlay-out .\docs\windows-port\blueprint\geometry-overlay.svg --fail-on-error
```

Expected: schema/artifact validation passes and geometry reports zero errors.
Inspect the SVG/HTML/rendered PNG and selected `diagram.png`; then remove
`geometry.json` and `geometry-overlay.svg` because they are review intermediates.

- [ ] **Step 6: Commit the regenerated Blueprint views**

```powershell
git add -- docs/windows-port/blueprint/diagram.svg docs/windows-port/blueprint/diagram.html docs/windows-port/blueprint/diagram.render.png docs/windows-port/blueprint/diagram.generated.png docs/windows-port/blueprint/diagram.png docs/windows-port/blueprint/BLUEPRINT.md
git commit -m "docs(windows): refresh maximized capture blueprint"
```

### Task 3: Produce the new acceptance report before removing the old report

**Files:**
- Create: `docs/windows-port/reports/WINDOWS_MAXIMIZED_NATIVE_VISUAL_WORKFLOW_REPORT.md`
- Create: `docs/windows-port/reports/WINDOWS_MAXIMIZED_NATIVE_VISUAL_WORKFLOW_REPORT.html`
- Delete after replacement passes: `docs/windows-port/reports/WINDOWS_NATIVE_VISUAL_WORKFLOW_REPORT.md`
- Delete after replacement passes: `docs/windows-port/reports/WINDOWS_NATIVE_VISUAL_WORKFLOW_REPORT.html`

**Interfaces:**
- Consumes: a fresh default `Capture-NativeVisuals.ps1` manifest and manual review of every generated local-only PNG.
- Produces: matching Markdown/HTML verdicts for the maximized-only workflow, without private evidence disclosure.

- [ ] **Step 1: Run a fresh formal release build and native capture**

Run from repository root without `-SkipBuild`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\Capture-NativeVisuals.ps1
```

Expected: completion summary reports `status=complete`,
`capture_runs=['fullscreen']`, dynamic screenshot count, and
`process_cleanup=confirmed`. The manifest keeps `size_runs=[]`.

- [ ] **Step 2: Manually inspect every fresh local screenshot**

Inspect Overview, every numbered Tasks/AI Leadership/Usage/Skills segment, and
the single Projects first viewport. Confirm every frame is maximized, long
panels reach their recorded end, Projects stays first-viewport-only, and no
horizontal clipping or selected-surface mismatch appears. Do not copy the
screenshots or their private contents into the report.

- [ ] **Step 3: Run the verification recorded by the new report**

Run from repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualCaptureWorkflow.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualDocumentation.ps1
uv run --with pyyaml python C:\Users\ADMIN\.cc-switch\skills\blueprint\scripts\validate_blueprint.py --schema .\docs\windows-port\blueprint\schema.yaml --artifacts-dir .\docs\windows-port\blueprint
git diff --check
```

Run from `windows/`:

```powershell
cargo +stable-x86_64-pc-windows-msvc test --workspace
```

Run from `windows/apps/codexu-tauri/web/`:

```powershell
npm run build
$testFiles = (Get-ChildItem .\tests\*.test.mjs).FullName
node --test $testFiles
```

Every command must exit 0 before its result is recorded as passed. Record the
existing Vite chunk warning as a non-blocking warning, not as a clean-output
claim.

- [ ] **Step 4: Write the paired replacement reports from the same evidence**

Both report formats must contain the same:

- verdict and date;
- checkout/commit identity without machine path;
- maximized exact-HWND and `-Surface` contract;
- dynamic per-surface capture counts from the new manifest;
- release build, preflight, PowerShell, Blueprint, Web, Rust, and cleanup results;
- manual-review conclusion and known gaps;
- statement that other client sizes remain reserved but unimplemented;
- privacy statement excluding screenshots, paths, raw text, IDs, and metrics.

The HTML must be a standalone static report derived from the Markdown facts,
with readable verdict, evidence, coverage, risks, and next steps.

- [ ] **Step 5: Verify report agreement before deleting history**

Check that verdict, date, checkout, screenshot total, per-surface counts,
verification results, and known gaps match in both files. Run:

```powershell
git diff --check -- docs/windows-port/reports/WINDOWS_MAXIMIZED_NATIVE_VISUAL_WORKFLOW_REPORT.md docs/windows-port/reports/WINDOWS_MAXIMIZED_NATIVE_VISUAL_WORKFLOW_REPORT.html
```

Expected: exit 0 and no disagreement found during manual comparison.

- [ ] **Step 6: Delete the obsolete paired two-size report**

Only after Steps 1-4 pass, delete:

```text
docs/windows-port/reports/WINDOWS_NATIVE_VISUAL_WORKFLOW_REPORT.md
docs/windows-port/reports/WINDOWS_NATIVE_VISUAL_WORKFLOW_REPORT.html
```

Do not delete `.planning/` records or Phase 4 design documents.

- [ ] **Step 7: Commit the report replacement**

```powershell
git add -- docs/windows-port/reports/WINDOWS_MAXIMIZED_NATIVE_VISUAL_WORKFLOW_REPORT.md docs/windows-port/reports/WINDOWS_MAXIMIZED_NATIVE_VISUAL_WORKFLOW_REPORT.html docs/windows-port/reports/WINDOWS_NATIVE_VISUAL_WORKFLOW_REPORT.md docs/windows-port/reports/WINDOWS_NATIVE_VISUAL_WORKFLOW_REPORT.html
git commit -m "docs(windows): replace legacy native capture report"
```

### Task 4: Run final repository verification

**Files:**
- Verify: all files modified by Tasks 1-3 plus the approved spec and this plan.

**Interfaces:**
- Consumes: completed maximized-only documentation, Blueprint, report pair, and current runtime/test contracts.
- Produces: fresh exit-code evidence and a clean scoped branch.

- [ ] **Step 1: Parse and run all native visual PowerShell tests**

Run:

```powershell
$files = @(
  '.\windows\scripts\Capture-NativeVisuals.ps1',
  '.\windows\scripts\tests\Test-NativeVisualCaptureWorkflow.ps1',
  '.\windows\scripts\tests\Test-NativeVisualCaptureCoverage.ps1',
  '.\windows\scripts\tests\Test-NativeVisualDocumentation.ps1'
)
foreach ($file in $files) {
  $tokens = $null
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path $file), [ref]$tokens, [ref]$errors
  )
  if ($errors.Count -gt 0) { $errors; exit 1 }
}
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualCaptureWorkflow.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualCaptureCoverage.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualDocumentation.ps1
```

Expected: parser and every test exit 0.

- [ ] **Step 2: Run Rust and Web validation serially**

Run Rust from `windows/`:

```powershell
cargo +stable-x86_64-pc-windows-msvc test --workspace
```

Run Web from `windows/apps/codexu-tauri/web/`:

```powershell
npm run build
$testFiles = (Get-ChildItem .\tests\*.test.mjs).FullName
node --test $testFiles
```

Expected: all commands exit 0. Keep any existing non-blocking Vite chunk-size
warning separate from failures.

- [ ] **Step 3: Confirm active-source cleanup and repository diff**

Search only active sources:

```powershell
rg -n "960.?760|720.?540|12 PNGs|Native Screenshot Demo" windows/README.md docs/windows-port/blueprint
git diff --check
git status --short
```

Expected: the active-source search finds no obsolete contract; historical
fixed-size references remain only in `.planning/` and Phase 4 design files.

- [ ] **Step 4: Confirm branch handoff state**

Run `git status --short` and `git log -4 --oneline --decorate`. Expected: no
uncommitted task files, the Task 1-3 commits are present, and no merge or push
has occurred.
