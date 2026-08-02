# Skills Surface Design

## Goal

Turn the Windows Dashboard Skills tab from a placeholder-looking list into a compact local-usage instrument panel that helps a user answer three questions quickly: which Skills are being used, how often they are used, and when they were last observed.

## Scope

- Use the existing `SkillUsage` fields: `name`, `source_label`, `load_count`, `thread_count`, and `last_loaded_at`.
- Keep all presentation local and privacy-safe. Do not add paths, prompts, tool arguments, source contents, raw identifiers, or network behavior.
- Keep the existing Dashboard tab contract and responsive layout.
- Preserve the existing Liquid Glass tokens, semantic colors, typography, and accessibility patterns.

## Proposed experience

The panel becomes a calm utility surface with three layers:

1. A heading row with a puzzle icon, the title `Skills`, the copy `Local Skill usage`, and a `Privacy filtered` status chip.
2. A summary strip with three compact metrics: tracked Skills, local reads, and sessions. The values are derived from the existing array and are shown as `--` only when no records are available; missing timestamps are not treated as a zero or a date.
3. A ranked list of up to 20 observations, sorted by load count and then most recent observation. Each row shows the Skill name, source label, session count, last-observed time, read count, and a relative activity bar. The bar is a visual comparison only and does not replace the exact read count.

When there are no records, the panel keeps a stable card height and explains that the local snapshot has not observed a `SKILL.md` read yet. When the `local` usage snapshot is unavailable, the parent already supplies an empty list; the panel uses the same non-authoritative empty state without inventing zero usage.

## Visual direction

Use a refined utility-instrument direction: quiet glass, crisp metric numerals, one blue accent for activity, and a faint inset list container. The panel should feel denser and more informative than the current list without introducing a new visual language. The relative bar uses a CSS custom property supplied by the component and the existing accent token; no new hard-coded color is introduced.

## Interaction and accessibility

- The surface is read-only; no filtering or navigation control is needed for this iteration.
- The list is marked as a semantic list, and each activity bar has an accessible label describing its relative intensity.
- Metric labels remain visible next to values; color is never the only status channel.
- Skill names remain readable and wrap safely rather than being replaced by generated ellipses.
- Respect the repository's reduced-motion rule.

## Validation

- Extend the Skills contract test to require the summary labels, privacy copy, relative activity treatment, and safe-field-only behavior.
- Run the web contract tests and TypeScript/Vite build.
- Build and launch the real Windows Tauri application, navigate to Skills, and capture the exact native window with the existing native visual workflow.
- Manually inspect the captured Skills surface at the repository's supported maximized/native capture size and retain the screenshot under ignored local artifacts only.
