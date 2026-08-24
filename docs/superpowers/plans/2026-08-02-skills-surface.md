# Skills Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Windows Dashboard Skills placeholder-style list with a privacy-safe local-usage instrument panel and verify it in the real native Tauri window.

**Architecture:** Keep the existing `SkillsPanel` boundary and `SkillUsage` model. Derive summary metrics and stable ranked rows inside the panel, add one focused CSS utility for relative activity bars, and leave Rust readers, IPC, and dashboard tab routing unchanged.

**Tech Stack:** React 18, TypeScript, Tailwind CSS, CSS custom properties, Lucide React, Node contract tests, Vite, Tauri Windows native visual capture.

## Global Constraints

- Use only the existing safe `SkillUsage` fields; never expose paths, prompts, tool input, source contents, raw logs, or sensitive identifiers.
- Do not invent missing data as zero; render unavailable values as `--` or an explanatory empty state.
- Reuse the existing Glass surface, semantic text, border, accent, and spacing tokens.
- Do not add a new dependency or change the Rust/IPC data contract.
- Do not persist screenshots or runtime data in tracked files; use `.local-artifacts/` for native capture output.

---

### Task 1: Lock the Skills surface contract

**Files:**
- Modify: `windows/apps/codexu-tauri/web/tests/skills-panel-contract.test.mjs`
- Reference: `windows/apps/codexu-tauri/web/src/components/SkillsPanel.tsx`
- Reference: `windows/apps/codexu-tauri/web/src/types/models.ts`

**Interfaces:**
- Consumes: the existing `SkillsPanel` source and `SkillUsage` interface.
- Produces: text/structure assertions for the summary strip, privacy copy, relative activity bars, safe fields, and empty-state wording.

- [ ] **Step 1: Add failing contract assertions**

  Extend the existing test to require all of these exact strings or source patterns:

  ```js
  assert.match(panel, /Local Skill usage/);
  assert.match(panel, /Tracked Skills/);
  assert.match(panel, /Local reads/);
  assert.match(panel, /Sessions/);
  assert.match(panel, /style=\{\{ '--skill-intensity':/);
  assert.match(panel, /aria-label=\{`Relative activity/);
  assert.match(panel, /Privacy filtered/);
  ```

  Keep the existing assertions that the model contains `load_count`, `thread_count`, and `last_loaded_at`, and does not contain `path`, `static_token_estimate`, or `static_byte_count`.

- [ ] **Step 2: Run the focused test and confirm it fails**

  Run from `windows/apps/codexu-tauri/web`:

  ```powershell
  node --test tests/skills-panel-contract.test.mjs
  ```

  Expected result: FAIL because the current component does not contain the new summary and relative-activity contract.

- [ ] **Step 3: Commit the contract test**

  ```powershell
  git add windows/apps/codexu-tauri/web/tests/skills-panel-contract.test.mjs
  git commit -m "test(windows): define Skills surface contract"
  ```

### Task 2: Implement the Skills instrument panel

**Files:**
- Modify: `windows/apps/codexu-tauri/web/src/components/SkillsPanel.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/index.css`

**Interfaces:**
- Consumes: `SkillUsage[]` from the existing `DashboardHome` call site.
- Produces: a read-only `SkillsPanel` with summary metrics, deterministic ranking, privacy copy, accessible activity bars, and stable empty state.

- [ ] **Step 1: Derive display data without changing the model**

  In `SkillsPanel`, calculate `totalReads`, `totalSessions`, and `maxReads` from finite non-negative values. Sort a copied array by descending `load_count`, descending `last_loaded_at` with null timestamps last, then `id` for deterministic rendering. Keep the existing 20-row cap.

- [ ] **Step 2: Replace the placeholder-style content with the three-layer panel**

  Keep the current icon and privacy copy. Add the `Local Skill usage` subtitle, three metric cells, and rows containing the exact read count, session count, source label, last-observed label, and a relative bar. Preserve text wrapping for names and do not display raw paths.

- [ ] **Step 3: Add the focused activity-bar styling**

  Add a small `.skill-activity-bar` component style in `index.css` using `var(--accent)` and the existing surface/border tokens. Read the per-row intensity from the `--skill-intensity` custom property and keep the bar decorative with an accessible label on the row.

- [ ] **Step 4: Run the focused contract test**

  ```powershell
  node --test tests/skills-panel-contract.test.mjs
  ```

  Expected result: PASS.

- [ ] **Step 5: Commit the implementation**

  ```powershell
  git add windows/apps/codexu-tauri/web/src/components/SkillsPanel.tsx windows/apps/codexu-tauri/web/src/index.css
  git commit -m "feat(windows): turn Skills into a usage instrument panel"
  ```

### Task 3: Verify the web surface and native window

**Files:**
- Modify: none unless verification exposes a focused defect.
- Artifacts: ignored files under `.local-artifacts/windows-visual-captures/` only.

**Interfaces:**
- Consumes: the built Tauri WebView and existing native capture workflow.
- Produces: passing web build/tests and a reviewed native Skills screenshot.

- [ ] **Step 1: Run all web contract tests and the production build**

  ```powershell
  Set-Location windows/apps/codexu-tauri/web
  node --test tests/*.test.mjs
  npm run build
  ```

  Expected result: all contract tests pass and Vite emits a successful production build.

- [ ] **Step 2: Run the Windows Rust workspace tests**

  ```powershell
  Set-Location E:/project/codexU/windows
  cargo test --workspace
  ```

  Expected result: the existing workspace tests pass without any Rust or IPC changes.

- [ ] **Step 3: Capture the real Skills surface**

  ```powershell
  Set-Location E:/project/codexU
  powershell -NoProfile -ExecutionPolicy Bypass -File windows/scripts/Capture-NativeVisuals.ps1 -Surface Skills
  ```

  Use the resulting exact-HWND native screenshot from `.local-artifacts/windows-visual-captures/`, inspect it with the image viewer, and confirm the Skills tab shows the new summary/list or the truthful empty state without raw local data.

- [ ] **Step 4: Run formatting/diff checks**

  ```powershell
  git diff --check
  git status --short
  ```

  Expected result: no whitespace errors; only the intended tracked files are changed and capture output remains ignored.

### Task 4: Merge the completed branch

**Files:**
- Modify: none during merge.

**Interfaces:**
- Consumes: the verified `codex/skills-surface` branch and its original base branch `codex/native-surface-capture-coverage`.
- Produces: a fast-forward or explicit merge into the original base branch, with the new branch retained unless the user later asks for cleanup.

- [ ] **Step 1: Record the verified branch state**

  ```powershell
  git status --short --branch
  git log --oneline --decorate -5
  ```

- [ ] **Step 2: Merge back to the original base branch**

  ```powershell
  git switch codex/native-surface-capture-coverage
  git merge --no-ff codex/skills-surface -m "merge: improve Windows Skills surface"
  ```

- [ ] **Step 3: Verify the merged result**

  ```powershell
  git status --short --branch
  git log --oneline --decorate -5
  git diff codex/native-surface-capture-coverage^ codex/native-surface-capture-coverage -- windows/apps/codexu-tauri/web/src/components/SkillsPanel.tsx windows/apps/codexu-tauri/web/src/index.css windows/apps/codexu-tauri/web/tests/skills-panel-contract.test.mjs
  ```

  Expected result: the base branch contains the tested Skills implementation, the worktree is clean apart from ignored local artifacts, and no unrelated files were merged.
