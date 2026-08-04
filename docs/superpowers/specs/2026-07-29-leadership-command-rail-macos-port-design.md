# Leadership Command Rail macOS Port Design

## Goal

Replace the Windows L1-L7 command rail with the same two-layer coordinate model used by macOS \`LeadershipRankProgressHeader\`, so badges, labels, threshold dots, score, and progress remain aligned at every supported width.

## Scope

- Change only the reusable Windows \`LeadershipCommandRail\` presentation in \`LeadershipPanel.tsx\` and its styles in \`index.css\`.
- Keep the existing \`LEADERSHIP_BANDS\` thresholds \`0/20/35/50/65/80/93\`, score semantics, current-band selection, click behavior, and accessibility labels.
- Do not change Tauri commands, IPC types, data readers, scoring, cache behavior, Dashboard navigation, or report/showcase files.

## Layout contract

The component has two sibling coordinate layers sharing the same horizontal safe inset (\`38px\`):

1. **Stage layer**: a fixed-height, relatively positioned frame containing seven fixed-width (\`62px\`) stage lockups. Every lockup is centered at its canonical threshold percentage, uses a fixed badge slot, and has the same vertical baseline. The active badge grows only within that fixed slot.
2. **Track layer**: a fixed-height track frame using the same inset and threshold percentages for the capsule, fill, dots, and score. The score text is inside the capsule and its horizontal position is clamped to preserve its full label at both ends.

There are no per-level placement rules and no dashboard-specific rail geometry overrides. Responsive behavior changes only shared dimensions and never the coordinate system.

## Visual rules

- Normal badges render at 29px in a 33px slot; the active badge renders at 33px in that same slot.
- Every stage uses the same label line and vertical gap; no L1 edge shift and no L6 size or vertical exception.
- Progress fill maps from the full 0-100 color domain and clips at the score.
- Each threshold dot uses the corresponding stage coordinate; current and completed dots retain existing semantic emphasis.
- Score text remains readable: use the accent foreground near zero and the elevated foreground elsewhere, and clamp it inside the track.

## Verification

- Add source-layout regression tests proving the stage and track layers both use the shared 38px inset, all seven stages use a fixed 62px lockup, and no L1/L6 placement exception remains.
- Run the focused rail test, the web build, Rust workspace tests, \`git diff --check\`, and a native Windows visual check at desktop width.

