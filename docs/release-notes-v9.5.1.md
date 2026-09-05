# Codex Account Manager Next v9.5.1

Release name: 0905v1

Build: 13 · Date: 2026-09-05

## Highlights

- Added GPT-6 Astra to the native model selector, with all six efforts advertised by the installed Codex CLI and Standard/Fast speed. Existing Sol/High/Standard defaults and saved preferences remain unchanged.
- The primary CLI and default subagents receive the same model and reasoning settings. Profile persistence, Apply to All and every Astra effort/speed combination have regression coverage.
- Introduced an identity-aware single-account workspace and menu-bar layout. Quota and the next task are prominent; advanced account management, statistics and automation remain accessible.
- Removed the duplicate Inspection page and its fixed Sol baseline. Account cards now show missing, stale or failed quota snapshots; Hub occupancy checks remain fail-closed.
- Refreshed native light/dark surfaces, responsive account cards, blue-purple model controls and press feedback. Native popovers respect Reduce Motion.
- Split the oversized entry point into app, services, domain and UI files, removed unmounted legacy views, centralized private file permissions, and unified formatting and the 25-test runner.
- Added original-resolution 2× screenshots generated from production SwiftUI components with synthetic data. Preview initialization does not migrate production preferences or read dispatch mappings.

## Verification

- Optimized Apple Silicon build: `make build BUILD_DIR=build-astra SWIFT_OPTIMIZATION='-O -warnings-as-errors'` — passed.
- Strict Swift formatting: `make lint` — passed.
- All 25 self-tests: `./scripts/run-self-tests.sh --skip-build --build-dir build-astra` — passed after the final source changes.
- Bundled PNG verification, macOS deployment compatibility script, plist validation and strict ad-hoc signature verification — passed.
- Global memory-risk gate — passed. Inventory reviewed: 20 Process creation sites, 15 Pipe sites, 22 Timer sites, 11 observer sites, 38 Data reads, no static mutable collection candidates and 13 parent-path traversal sites. This structural gate is not a soak test.
- Native fixture rendering: system-only, single managed account and multiple accounts; dark/light; 860/1080-point workspaces, menu-bar and model editor previews.
- In-place upgrade: the existing `build/CodexAccountManagerNext.app` was replaced, not copied to a second installation directory. Installed metadata is `0905v1 / 9.5.1 (13)`; the running executable path and hash were verified.
- Live UI smoke check: the workspace opened without Inspection navigation; GPT-6 Astra appeared in the native model menu; the effort slider, Fast switch, Apply to All and account task badges were present. The model menu was dismissed without changing saved preferences.

## Runtime acceptance boundaries

- No real login, Desktop account switch, manual warm-up, webhook notification or paid Next-to-CLI Astra task was started during this acceptance pass. These behaviors are not claimed as end-to-end verified.
- Existing opted-in background refresh and automation settings were preserved. Reopening Next resumes its normal background behavior.
- The separate companion Hub's Astra model-validation source patch passed its Go tests, but its running service was not replaced or restarted. Installing Next does not deploy that service. A Hub with an older allowlist still needs a separately verified compatible upgrade before accepting Astra dispatch.
- Single-account and alternate-appearance captures use synthetic fixtures, not a destructive reduction of the user's real account list. No real-account screenshots are published here.
- macOS 13 remains the deployment target. This local pass ran on Apple Silicon with Swift 6.3.2; it did not run the app on macOS 13 or Intel hardware. Windows packaging, a long-duration soak and Apple notarization were not performed.
- This record describes a local app upgrade and source publication. No v9.5.1 release tag, DMG/MSI/EXE distribution or formal GitHub Release was created.

## Previous-version recovery

The previous `0904v2 / build 12` app is retained as the sole ZIP in the local release-archives folder. The older `0904v1 / build 11` ZIP was moved to Trash only after both ZIP blobs were verified on the [GitHub backup branch](https://github.com/BLACKIELF/codex-account-manager-next/tree/archive/app-backups). Account credentials and support data are not part of these app-only archives.

## Checksums

| Artifact | SHA-256 |
| --- | --- |
| Installed 0905v1 Apple Silicon executable | `a7e0e488b71050228a9efdb4b33a7e6ed36a57390b29ed92ea6a55fe885004a5` |
| Previous app ZIP, 0904v2 / build 12 | `4986b681260409cef3ceae47a0c55268d8d0ebf415e3207573bc4b0a1bd815e2` |
| Archived older app ZIP, 0904v1 / build 11 | `39a4266c0e6dcbf1501d31437e1a0c2a63429785f03140cec167e378e3894f91` |
| Single-account dark screenshot, 2160 × 1520 | `c27a5a6084af696355273834c5d2145f395dd81e3ab6ef5d6acf3e999516fa3e` |
| Multi-account light screenshot, 2160 × 1520 | `7f0ddb3ea1a2a3503c7143ee1becb3efdd8762fd9d83c0f988359a6bdbe1e888` |
| Single-account menu screenshot, 760 × 1220 | `5da81475f3bd88769f7fce3e97cbf95592ee3c0096834239453d3beb5268f78c` |
| Astra editor screenshot, 800 × 940 | `0f3edf236ab732278e06abf70e055685ea8c9505bdd11613e4ee8f6c39307ccf` |
