# Windows Dashboard Source-Hierarchy Alignment Design

Date: 2026-07-29
Status: Approved design; implementation not started

## Decision

The macOS `UsageWidgetView` is the source of truth for the Windows Dashboard's view hierarchy. This is a source-level port of page composition and interaction order, not a screenshot-led redesign.

The Windows dashboard will have one content navigation system, matching macOS:

1. Today tasks
2. AI Leadership
3. Usage trend
4. Project ranking
5. Skill

`AI Leadership` is therefore a lower Dashboard tab. The overview may retain a compact, clickable leadership entry, as macOS does, but it must not render the full leadership rail, leadership facts, or leadership-detail panels.

## macOS Source Contract

`Sources/CodexUsageWidget/main.swift` defines the layout contract:

- `DashboardTab` contains exactly `tasks`, `leadership`, `usage`, `projects`, and `skills`; its default selection is `tasks`.
- `widgetContent` renders `usageOverviewSection` before `dashboardTabsSection`.
- `usageOverviewSection` has a compact leadership command-radius entry, quota visual, three detailed token cards, and month-value progress.
- The full `LeadershipDashboardPanel` is rendered only from the `leadership` case of the Dashboard tab switch.

The Windows implementation must preserve this information hierarchy even where a platform-specific data source is unavailable. Unavailable quota, task, or other fields must remain visibly unavailable; the port must not manufacture values in order to reproduce the macOS layout.

## Current Windows Mismatch

Windows currently has an invented outer navigation (`Dashboard`, `AI Leadership`, `Threads`) in `Dashboard.tsx`, while `DashboardHome.tsx` has a second inner navigation that omits `AI Leadership`. It also renders the full leadership orbit, command rail, and four leadership facts before the inner tabs.

This duplicates navigation and promotes a drill-down subject into the Dashboard's primary content. It is not equivalent to the macOS source structure.

## Target View Structure

```text
Dashboard window
|- Header and local-source status
|- Usage overview
|  |- Compact leadership command entry -> selects AI Leadership
|  |- Quota / reset slot, with an explicit unavailable state when needed
|  |- Today / 7-day / lifetime token cards
|  `- Month-value progress
`- Dashboard content tabs
   |- Today tasks
   |- AI Leadership -> LeadershipPanel
   |- Usage trend -> UsagePanel
   |- Project ranking -> ProjectsPanel
   `- Skill -> current honest unavailable state
```

Recent threads remain distinct local records. They must not be relabelled as tasks merely to fill the macOS task slot. The task tab will retain an explicit unavailable state until a genuine task-board contract exists.

## Implementation Boundaries

Included:

- Refactor `Dashboard.tsx` and `DashboardHome.tsx` so there is one Dashboard tab state and one tab bar.
- Move the complete `LeadershipPanel` into the inner `AI Leadership` tab.
- Remove the home-level command rail and leadership-facts sections.
- Recompose the overview with named CSS grid areas for desktop and stacked regions for compact windows.
- Preserve existing local-only labels, empty states, keyboard tab navigation, and current data semantics.
- Add focused component/layout tests for the source hierarchy.

Excluded:

- Rust reader, aggregation, cache, IPC, scoring, quota, thread, or task data-contract changes.
- Enabling Claude Code on Windows.
- Inventing quota, monetary, task, or score data unavailable from the current snapshot.
- Pixel-copying macOS artwork, background treatment, or non-Windows window chrome.

## Acceptance Criteria

1. Windows has no outer `AI Leadership` route competing with Dashboard content tabs.
2. The default content tab is Today tasks.
3. The sole Dashboard tab bar contains Tasks, AI Leadership, Usage, Projects, and Skill, in that order.
4. Selecting the compact overview leadership entry selects the lower AI Leadership tab.
5. The leadership rail, leadership dimensions, and leadership trend render only in the AI Leadership tab.
6. The overview uses actual local values or explicit unavailable states; it never substitutes zero or fabricated quota/cost data.
7. Keyboard navigation and focus semantics remain valid for the unified tab bar.
8. Web build, Rust workspace tests, layout/source-hierarchy tests, `git diff --check`, and a fresh native Windows screenshot all pass before visual acceptance is claimed.

## Verification Plan

- Add a focused test that asserts the unified tab order, Tasks default state, and absence of full leadership detail in the overview tree.
- Build the web bundle and run the workspace test suite.
- Build the native Tauri executable from `E:\project\codexU\windows`.
- Open the rebuilt native app and capture a new screenshot for comparison against the macOS source structure; no earlier screenshot can count as post-change evidence.
