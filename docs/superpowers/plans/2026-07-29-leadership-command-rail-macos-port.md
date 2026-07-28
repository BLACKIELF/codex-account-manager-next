# Leadership Command Rail macOS Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (\`- [ ]\`) syntax for tracking.

**Goal:** Rebuild the Windows L1-L7 command rail around macOS's two-layer shared-coordinate model.

**Architecture:** \`LeadershipCommandRail\` will render a fixed-height stage layer and a sibling track layer. Both layers will use the same 38px safe inset and canonical threshold percentages; CSS will own only shared dimensions and current-state emphasis, not level-specific positioning.

**Tech Stack:** React, TypeScript, CSS custom properties, Node test runner, Vite, Tauri/Rust.

## Global Constraints

- Retain \`LEADERSHIP_BANDS\`, score mapping, active-band semantics, click handling, and accessibility labels.
- Do not change data readers, scoring, IPC, cache behavior, or Dashboard navigation.
- Do not modify generated artifacts or unrelated user changes.
- Use existing palette tokens; do not add hard-coded colors.
- Verify in the running native Windows app; code review and build output alone are not visual acceptance.

---

### Task 1: Lock down the shared-coordinate layout contract

**Files:**

- Modify: \`windows/apps/codexu-tauri/web/tests/leadership-rail-layout.test.mjs\`
- Modify: \`windows/apps/codexu-tauri/web/src/components/LeadershipPanel.tsx:333-430\`
- Modify: \`windows/apps/codexu-tauri/web/src/index.css:276-466\`

**Interfaces:**

- Consumes: \`bands: readonly LeadershipBand[]\`, \`hasSignal: boolean\`, \`score: number\`, and optional \`onOpenLeadership\`.
- Produces: \`LeadershipCommandRail\` with a stage layer and track layer that share \`--leadership-rail-inset: 38px\`.

- [ ] **Step 1: Write the failing layout test**

\`\`\`js
assert.match(component, /className="leadership-rail-stage-layer"/);
assert.match(component, /className="leadership-rail-track-layer"/);
assert.match(stylesheet, /--leadership-rail-inset:\\s*38px/);
assert.match(stylesheet, /\\.leadership-rail-stage\\s*\\{[\\s\\S]*?width:\\s*62px/);
assert.doesNotMatch(stylesheet, /leadership-rail-badge-(large|left-edge)|leadership-rail-node-left-edge/);
\`\`\`

- [ ] **Step 2: Run the focused test and verify it fails**

Run: \`node --test tests/leadership-rail-layout.test.mjs\`

Expected: FAIL because the component still renders \`leadership-threshold-points\` and CSS still contains per-level exception classes.

- [ ] **Step 3: Implement the two sibling layers**

\`\`\`tsx
<div className="leadership-rail-stage-layer">
  {bands.map((band) => <div className="leadership-rail-stage" style={{ left: \`\${band.scoreMin}%\` }} />)}
</div>
<div className="leadership-rail-track-layer" style={{ ['--rail-progress' as keyof CSSProperties]: \`\${safeScore}%\` }}>
  <div className="leadership-rail-track" />
  <div className="leadership-rail-fill" />
  {bands.map((band) => <span className="leadership-rail-dot" style={{ left: \`\${band.scoreMin}%\` }} />)}
  <span className="leadership-rail-score-text" />
</div>
\`\`\`

Remove \`leadership-threshold-points\`, score stem/pin, all left-edge and large-badge class emission, and their CSS rules. Keep the screen-reader status text and the optional button wrapper.

- [ ] **Step 4: Run the focused test and verify it passes**

Run: \`node --test tests/leadership-rail-layout.test.mjs\`

Expected: PASS with every assertion satisfied.

- [ ] **Step 5: Commit the focused implementation**

\`\`\`powershell
git add windows/apps/codexu-tauri/web/src/components/LeadershipPanel.tsx windows/apps/codexu-tauri/web/src/index.css windows/apps/codexu-tauri/web/tests/leadership-rail-layout.test.mjs
git commit -m "fix(windows-ui): port leadership rail layout"
\`\`\`

### Task 2: Verify build and native visual alignment

**Files:**

- Verify only: \`windows/apps/codexu-tauri/web/src/components/LeadershipPanel.tsx\`
- Verify only: \`windows/apps/codexu-tauri/web/src/index.css\`

**Interfaces:**

- Consumes: the completed \`LeadershipCommandRail\` from Task 1.
- Produces: fresh build, test, whitespace, and native visual evidence.

- [ ] **Step 1: Build the frontend**

Run: \`npm run build\` from \`windows/apps/codexu-tauri/web\`.

Expected: exit code 0.

- [ ] **Step 2: Run Rust workspace tests**

Run: \`cargo test --workspace\` from \`windows\`.

Expected: exit code 0 with no test failures.

- [ ] **Step 3: Check whitespace and scope**

Run: \`git diff --check\` and \`git status --short\` from the isolated worktree.

Expected: no whitespace errors; only the committed rail implementation and internal design/plan documents are present.

- [ ] **Step 4: Inspect the native app**

Build and launch the Windows Tauri app from the isolated worktree, open AI Leadership at desktop width, and verify all seven stage lockups share a baseline, no badge clips at L1/L7, dots line up with stage centers, and the score remains inside the track.

- [ ] **Step 5: Record actual outcome before handoff**

Report the commands and their exit status separately from the native visual result. If native inspection is unavailable, state that as an unverified acceptance gap.

