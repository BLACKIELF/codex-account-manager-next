# macOS / Windows Dashboard Feature Comparison (non pixel-perfect)

This document keeps the README screenshot order and maps each macOS section to the best Windows native evidence in one-to-one comparison rows.

Legend:

- `fixed overview`: fixed hierarchy block
- `variable panel`: variable area with different mapping strategy
- `partial`: partial parity (same theme, not full one-to-one feature semantics)
- `not implemented`: missing as an independent page/feature in current release
- `outside Dashboard + partial`: same functional area, different host layer

## 1. Information structure alignment

```text
macOS README sections:
AI Leadership, Today, Usage, Projects, Skills

Windows:
Dashboard Home (includes Leadership + Token mix + Today/7-Day/Lifetime),
then existing detailed tabs.
```

Windows does not currently expose all README cards as independent pages under one path; the comparison uses the highest-fidelity same-level evidence in those cases.

## 2. Fixed overview

### 2.1 AI Leadership / Dashboard Overview

| macOS (README) | Windows |
| --- | --- |
| ![macOS AI Leadership](../../screenshot-v1.2.0-ai-leadership.png) | ![Windows Dashboard Home](../reports/assets/dashboard-home-native.png) |

- Tag: `fixed overview`
- Windows presents leadership context in the default Dashboard Home with local 7-day Token mix and Today/7-Day/Lifetime summary, then progression rail.

## 3. Variable panels (aligned to README order)

### 3.1 Today / Tasks (`variable panel` + `not implemented`)

| macOS | Windows |
| --- | --- |
| ![macOS Today](../../screenshot-v0.3.0-today.png) | ![Windows Dashboard Home (Today metric in top cluster)](../reports/assets/dashboard-home-native.png) |

- Tag: `variable panel` + `not implemented`
- Windows does not provide a standalone Today/Tasks page in this release. The same semantic slot is shown in the Dashboard Home top usage cluster.

### 3.2 Usage (`variable panel` + `partial`)

| macOS | Windows |
| --- | --- |
| ![macOS Usage](../../screenshot-v0.3.0-usage.png) | ![Windows Usage](assets/dashboard-usage-home.png) |

- Tag: `variable panel` + `partial`
- Windows shows local token-based usage with Home scope controls and chart context; naming and metric sources differ by platform contract.

### 3.3 Projects (`variable panel` + `partial`)

| macOS | Windows |
| --- | --- |
| ![macOS Projects](../../screenshot-v0.3.0-projects.png) | ![Windows Projects](assets/dashboard-projects-native.png) |

- Tag: `variable panel` + `partial`
- Windows shows project-related ranking as a native equivalent at the matched hierarchy level.

### 3.4 Skills (`variable panel` + `not implemented`)

| macOS | Windows |
| --- | --- |
| ![macOS Skills](../../screenshot-v0.3.0-skills.png) | ![Windows Tool usage](assets/dashboard-tools-nearest-skills.png) |

- Tag: `variable panel` + `not implemented`
- Windows has visible nearest tool usage evidence; a first-class dedicated Skills section is not yet represented as a separate native page.

## 4. Settings / Palette (outside dashboard + partial)

| macOS | Windows |
| --- | --- |
| ![macOS Palette gallery](../../screenshot-v1.1.0-palette-gallery.png) | ![Windows Settings](assets/settings-dashboard-native.png) |

- Tag: `outside Dashboard + partial`
- Both sides expose configuration entry points; the container surface and control surface differ by OS conventions.

## 5. Alignment summary

- `AI Leadership` is mapped as fixed overview (semantic parity, contract-different content source).
- `Today / Tasks` and `Skills` are `variable panel + not implemented` (no independent page in current Windows build).
- `Usage` and `Projects` are `variable panel + partial` (equivalent native surfaces, different data surface details).
- `Settings / Palette` remains `outside Dashboard + partial`.
