# Windows Native Surface Capture Coverage Design

## Status and scope

This design is approved for implementation. It corrects the native visual
workflow's vertical coverage without changing Dashboard UI, local data,
Tauri IPC, or the exact-HWND Windows Graphics Capture engine.

The current workflow selects a Dashboard tab, scrolls until the selected tab
and any part of its panel are visible, and writes one image per surface. That
proves navigation but leaves the lower content of tall panels unobserved.

## Selected approach

Use one maximized exact-HWND run for the complete evidence set. Capture the
selected panel itself as a sequence of real native viewports:

1. Maximize the real Tauri window and verify that Win32 reports it maximized.
2. Capture one page-top Overview from that maximized window.
3. Select the target Dashboard tab.
4. Align the beginning of the selected panel near the top of the client area.
5. Capture the first panel viewport without reserving space for the page
   header or tab row.
6. Scroll by a viewport-relative step and capture further segments until the
   selected panel's end is visible. A stable page end before the panel end is
   a capture failure.
7. Keep a small vertical overlap between neighboring images so a reviewer can
   follow layout continuity.

Short panels and empty states produce one segment. Tall panels produce as many
segments as required by the current data and maximized viewport. Projects is
an explicit first-viewport-only exception; its internal list is not scrolled.
File names and the manifest identify the surface, so the selected tab does not
need to remain in every frame.

This preserves actual WebView2 viewport behavior. It deliberately avoids a
stitched full-page image, DOM screenshot, fixture, baseline, or pixel diff.

## Capture and manifest contract

- `Overview` is one page-top image in the single maximized run.
- Every selected Dashboard surface produces `slug-01.png` through
  `slug-NN.png` under `screenshots/fullscreen/`.
- Each capture record contains the surface, segment index, first/last flags,
  scroll step count, panel-start visibility, panel-end visibility, page-end
  fallback, file, frame size, and byte count.
- A surface is complete only when its first segment covers the panel start and
  its final segment covers the panel end. Projects is complete after its first
  panel viewport is recorded with the explicit exception in the manifest.
- The workflow no longer requires a fixed total of 12 PNGs. Its manifest
  records the actual segment count and per-surface completion.

## Failure behavior

The workflow fails closed when it cannot locate the panel, cannot align its
start, cannot advance scrolling, or cannot establish an end condition within
the bounded segment limit. Process ownership, exact executable checks, local
artifact boundaries, and cleanup rules remain unchanged.

## Alternatives not selected

- One screenshot with the tab visible: insufficient vertical coverage and
  wastes client-area height.
- One screenshot at the panel bottom: hides the panel beginning and does not
  establish continuity.
- A stitched long screenshot: does not preserve the real viewport states that
  expose clipping, sticky elements, and scroll behavior.

## Verification

- A focused PowerShell regression test must fail against the old fixed-frame
  contract and pass only when dynamic segment coverage is exposed by preflight.
- The workflow preflight must continue to prove exact HWND, maximized-window
  mode, release executable identity, configured surfaces, and local-only output.
- PowerShell parsing, the workflow regression test, Web contracts/build, Rust
  workspace tests, and `git diff --check` are run before commit.
- A fresh native capture is required to claim real end-to-end surface coverage;
  code/preflight tests alone prove only the workflow contract.
