# Windows Dashboard Home Design

**Status:** approved direction, 2026-07-27
**Scope:** Windows Tauri presentation layer and static showcase only

## Goal

Turn the Windows app's default view into a real, high-density Dashboard that carries the macOS reference's information hierarchy: leadership identity first, a central usage focus, concise key metrics, then the rank path and trends. AI Leadership remains a focused detail view rather than the entire home page.

## Design position

The product stays a quiet, local-first Liquid Glass utility. The result is not a dark promotional clone: it keeps the Windows light/system theme, system typography, semantic palette tokens, and readable surfaces. Its memorable element is a single, unified leadership-and-usage instrument cluster—not a page of unrelated cards, gradients, or decorative effects.

## Existing-data boundary

The current Tauri commands expose `LocalUsage`: local Token totals, detailed Token splits, daily/long-range trends, projects, tools, and the Leadership snapshot. They do **not** expose an official quota/rate-limit response. Although the core has a `RateWindow` model, the active Windows `AppState` neither reads nor caches it.

Therefore this scope does not add a reader, cache, IPC field, estimate, or placeholder quota percentage. The dashboard's central usage focus is a clearly labelled seven-day Token mix and total; it is not presented as official remaining allowance.

## Information architecture

`Dashboard` gains a default `home` tab. Existing tabs remain, with `AI Leadership` retained as the detailed diagnostic view and `Usage`, `Threads`, and `Projects` retained unchanged as their dedicated surfaces.

At a desktop window around 960–1280px wide, the home view is arranged in this stable order:

1. A shared top instrument row:
   - compact Leadership command-radius summary and its four honest 28-day metrics;
   - a seven-day Token mix focus with total and input/cached/output composition;
   - Today, 7-day, and Lifetime usage summaries.
2. A full-width Leadership progression rail using the real L1–L7 badges, canonical lower thresholds `0/20/35/50/65/80/93`, and the current score marker. It opens the detailed Leadership tab.
3. A balanced two-column lower row: seven-day bars and long-range usage trend.
4. Existing detailed tabs for Leadership, Usage, Threads, and Projects.

At narrow widths, the instrument row and lower chart row stack without changing their content order. Refreshes preserve fixed card dimensions and do not replace missing values with zero.

## Components and responsibilities

- `Dashboard.tsx` owns tab selection, the default home route, and existing data hooks.
- `DashboardHome.tsx` is a presentation-only composition over `LocalUsage` and `LeadershipDashboardSnapshot`; it does not invoke Tauri and never computes product scores.
- `LeadershipPanel.tsx` retains the detailed view. Its compact, reusable overview and progression primitives are extracted only when doing so removes duplicated visual/data mapping.
- `UsageMixFocus.tsx` renders the real Token composition from `DetailedUsage.seven_day`; its labels make clear that the values are local Token usage, not account quota.
- Existing `StatCard`, `TokenBarChart`, and `TrendChart` stay the canonical sources for their existing facts and interaction behavior.

## Interaction and accessibility

- The tab row uses the existing arrow-key model and gains a `Dashboard` label with a dashboard icon from the existing Lucide family.
- The Leadership summary and progression rail are keyboard-reachable controls that open the Leadership detail tab; their accessible text contains score/title only when a valid Leadership signal exists.
- No-signal state uses a neutral orbit, `Record insufficient`, and no inferred rank or colored progress rail.
- Token mix and charts keep text labels, exact tooltip values, and semantic color roles; color is never the sole discriminator.

## Static showcase

After native acceptance, create `docs/windows-port/showcase/WINDOWS_DASHBOARD_SHOWCASE.md` and `.html`. Both pages use final, real native screenshots and document the mapping from macOS hierarchy to Windows product surfaces, retained platform differences, validation, and known gaps. They are showcase documents, not a fabricated landing page or a deployed site.

## Acceptance

- At 960×760-ish native size, the home page shows Leadership identity, seven-day Token focus, three usage summaries, and the L1–L7 progression without clipping.
- The progression uses existing assets and exact canonical mapping; its 0–100 color domain is clipped at score rather than compressed into the completed segment.
- No new data reader, cache behavior, score calculation, thread parsing, network use, or raw local content exposure is introduced.
- `npm run build`, `cargo test --workspace`, `cargo tauri build --no-bundle`, and `git diff --check` pass.
- The final pair of showcase documents and the parity report agree on screenshots, conclusions, validation, and retained differences.
