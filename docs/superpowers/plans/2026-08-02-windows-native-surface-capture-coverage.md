# Windows Native Surface Capture Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Produce one maximized exact-HWND native evidence set whose numbered
subpanel images cover the useful vertical content without duplicating fixed
client-size screenshots.

**Architecture:** Keep the existing release-app launch, UI Automation,
renderer-HWND scrolling, Windows Graphics Capture, local-artifact boundary,
and exact process cleanup. Replace the two fixed client-size runs with one
Win32-verified maximized run. Capture one Overview, then align and capture each
selected panel. Projects records only its first maximized panel viewport.

## Constraints

- Do not change Dashboard UI, data readers, local data, Tauri IPC, or product
  semantics.
- Every Overview and subpanel PNG must come from the same maximized exact HWND.
- Keep approximately 20% overlap between consecutive tall-panel viewports.
- Projects must produce exactly one first-panel-viewport PNG.
- Keep private screenshots, logs, runtime data, and machine paths under the
  Git-ignored `.local-artifacts/windows-visual-captures/` tree.

## Task 1: Lock the maximized-run contract

**Files:**

- `windows/scripts/tests/Test-NativeVisualCaptureWorkflow.ps1`
- `windows/scripts/tests/Test-NativeVisualCaptureCoverage.ps1`

- [x] Assert one `fullscreen` run and no fixed client-size runs.
- [x] Assert `window_mode = maximized exact HWND`.
- [x] Assert one `fullscreen/overview.png` plus numbered panel images.
- [x] Assert Projects has exactly one first-viewport record.
- [x] Observe the preflight failure before production changes.

## Task 2: Implement the single maximized capture

**File:** `windows/scripts/Capture-NativeVisuals.ps1`

- [x] Add Win32 maximize and `IsZoomed` verification.
- [x] Launch one task-local app instance and capture all surfaces from it.
- [x] Capture Overview once at page top.
- [x] Align every subpanel start and capture bounded numbered segments.
- [x] Stop Projects after its first panel viewport; require panel-end evidence
  for the other surfaces.
- [x] Record dynamic capture count and verify exact process cleanup.

## Task 3: Document the workflow

**Files:**

- `docs/windows-port/WINDOWS_NATIVE_VISUAL_WORKFLOW.md`
- `docs/superpowers/specs/2026-08-02-windows-native-surface-capture-coverage.md`

- [x] Replace the two-size artifact tree with `screenshots/fullscreen/`.
- [x] Document dynamic numbered sequences and the Projects exception.
- [x] Update the manual review checklist to inspect every generated image.

## Task 4: Verify and commit

- [x] Parse all PowerShell entry/test files.
- [x] Pass preflight and real native coverage regression tests.
- [x] Run a fresh formal capture without `-SkipBuild` and inspect the Overview,
  subpanel starts/ends, and Projects first viewport.
- [x] Pass Rust workspace tests, Web build/contracts, and `git diff --check`.
- [x] Stage only scoped files and commit as
  `fix(windows): cover maximized native dashboard panels`.
