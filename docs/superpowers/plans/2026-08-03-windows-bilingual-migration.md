# Windows Bilingual Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the macOS Chinese/English interface capability into the current Windows Tauri dashboard without changing panel structure, data semantics, or Tasks privacy boundaries.

**Architecture:** Persist `InterfaceLanguage` (`auto`, `zh-Hans`, `en`) in the Rust `AppConfig`. The WebView resolves `auto` from `navigator.language`, provides a typed message table through `I18nProvider/useI18n`, and synchronizes the effective language to Rust so settings-window and tray labels follow the same runtime language. Existing components retain their data and layout contracts and consume localized messages at render time.

**Tech Stack:** Rust/Serde/Tauri 2, React 18, TypeScript, Vite, Node `node:test` contract tests.

## Global Constraints

- Do not modify `Sources/CodexUsageWidget/main.swift`.
- Do not restore old bilingual branches, add Claude, merge `main`, push, or create screenshots.
- Preserve DashboardHome's Tasks/Leadership/Usage/Projects/Skills structure.
- Preserve safe Tasks titles, state icons, refresh summaries, and privacy-safe readers.
- Never read session JSONL or display raw prompts, replies, tool arguments, raw logs, paths, or financial content.
- Run RED tests before production implementation, then the requested Web/Rust build and formatting gates.

---

### Task 1: Rust language setting and runtime synchronization

**Files:**
- Modify: `windows/apps/codexu-tauri/src-tauri/src/app_state.rs`
- Modify: `windows/apps/codexu-tauri/src-tauri/src/commands/settings.rs`
- Modify: `windows/apps/codexu-tauri/src-tauri/src/tray.rs`
- Modify: `windows/apps/codexu-tauri/src-tauri/src/main.rs`
- Test: `windows/apps/codexu-tauri/src-tauri/src/app_state.rs` unit tests

**Interfaces:**
- `InterfaceLanguage` serializes as `auto`, `zh-Hans`, or `en`, with `Auto` as the serde default.
- `ResolvedLanguage` is the runtime-only language sent by the WebView.
- `sync_runtime_language` updates the shared runtime language and refreshes window/tray labels.

- [x] Write the failing enum-serialization and legacy-settings-default tests.
- [x] Run the targeted Rust tests and confirm they fail because the language type/field is absent.
- [x] Add the enum, serde default, config field, request field, runtime state, and localized window/tray update helpers.
- [x] Run the targeted Rust tests and confirm they pass.

### Task 2: Typed Web i18n resolver and provider

**Files:**
- Create: `windows/apps/codexu-tauri/web/src/i18n/messages.ts`
- Create: `windows/apps/codexu-tauri/web/src/i18n/I18nProvider.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/types/settings.ts`
- Modify: `windows/apps/codexu-tauri/web/src/hooks/useSettings.ts`
- Modify: `windows/apps/codexu-tauri/web/src/App.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/main.tsx`
- Test: `windows/apps/codexu-tauri/web/tests/bilingual-i18n.test.mjs`

**Interfaces:**
- `resolveInterfaceLanguage(preference, browserLanguage)` returns `zh-Hans` for Chinese browser tags and `en` otherwise.
- `getMessages(language)` returns the typed message table.
- `useI18n()` exposes `{ language, preference, setPreference, t }`.
- Settings persistence uses the existing `get_settings`/`set_settings` commands; effective language is synchronized through `sync_runtime_language`.

- [x] Write tests for auto/Chinese/English resolution and Dashboard/Tasks/Settings message selection.
- [x] Run the new Web tests and confirm the missing provider/table fails the assertions.
- [x] Implement the typed table, provider, runtime sync, and settings type wiring.
- [x] Run the new Web tests and confirm they pass.

### Task 3: Localize current Windows surfaces

**Files:**
- Modify: `windows/apps/codexu-tauri/web/src/windows/Dashboard.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/windows/Settings.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/Header.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/DashboardHome.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/TaskBoardPanel.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/SkillsPanel.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/UsagePanel.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/UsageHeatmap.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/TrendChart.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/TokenBarChart.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/ProjectsPanel.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/ProjectBoard.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/ToolUsageList.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/QuotaOverview.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/MonthlyValueProgress.tsx`
- Modify: `windows/apps/codexu-tauri/web/src/components/LeadershipPanel.tsx`

- [x] Replace visible static labels, empty/error/loading states, refresh text, status badges, and accessible labels with `t(...)` calls.
- [x] Keep existing tab order, data values, component boundaries, and privacy-safe task/skill fields unchanged.
- [x] Run all Web contract tests and the production build.

### Task 4: Full verification and focused commit

- [x] Run all Web contract and bilingual tests.
- [x] Run `npm run build`, `cargo test --workspace --all-targets`, `cargo check --workspace --all-targets`, `cargo fmt --all -- --check`, and `git diff --check`.
- [x] Inspect the final diff for macOS changes, privacy regressions, unrelated files, and generated artifacts.
- [x] Create one focused commit on `windows-port/ui-dev`; do not merge or push.
