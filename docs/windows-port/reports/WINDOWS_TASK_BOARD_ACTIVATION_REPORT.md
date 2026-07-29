# Windows Task Board Activation Report

**Date:** 2026-07-29
**Verdict:** Implemented; final native acceptance is blocked by unrelated dirty-worktree compilation failure.

## Scope and boundary

This activation ports only the trustworthy Codex task path to the Windows Tauri dashboard. It preserves the existing `UsageSnapshot.task_board` IPC types and the established lower Dashboard hierarchy.

- Reads only local state-database task metadata and active automation metadata.
- Excludes `subagent` threads.
- Presents fresh local metadata as **Recent activity**, older same-day metadata as **To continue**, and explicit archive evidence as **Archived today**.
- Never labels archival as completion or success.
- Includes a scheduled automation only when its metadata says `ACTIVE` and its kind/schedule is validated.
- Does not read session JSONL, previews, raw prompts, replies, tool arguments, raw logs, or full workspace paths for the board.

## Delivered changes

| Area | Change |
| --- | --- |
| Core reader | Added `codex_task_board.rs`, a read-only state/automation reader that returns the existing four-column task-board payload. |
| Dashboard snapshot | Populates the existing `task_board` field without changing its serialized type. |
| Dashboard UI | Replaced the Task-tab placeholder with a non-clickable Liquid Glass board; it shows title, shortened workspace label, factual time, and a textual state. |
| Empty and unavailable states | Distinguishes no available source from an available source with no trusted records. |
| Regression tests | Added sanitized SQLite classification/empty-board tests and a source contract for privacy-safe Task-tab rendering. |

## Validation evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Focused Rust task-board tests | Previously passed; currently blocked | 2/2 passed before a later unrelated dirty Skill-model edit. The latest rerun now stops before test execution at the unrelated `SessionSummary.skill_loads` mismatch. |
| Focused web Task-tab contract | Pass | 2/2: Dashboard mounts the panel, empty state is present, and technical identifiers/raw status are not rendered. |
| Web production build | Pass | `npm run build` completed; Vite emitted only its existing large-chunk advisory. |
| Full Rust workspace tests | Blocked | 35/36 core library tests passed; an unrelated pre-existing Skill-usage test failed in dirty `codex_transcript.rs`. |
| Rust formatting check | Blocked | Differences are confined to pre-existing dirty Tauri app-state/command files, not this Task Board change. |
| Tauri production build | Blocked | Compilation stops at the same unrelated `SessionSummary.skill_loads` model mismatch before a current executable is produced. |
| Diff whitespace check | Pass | `git diff --check` completed without whitespace errors. |
| Native UI acceptance | Not run | A current Tauri executable could not be built; no stale binary or historical screenshot was used as substitute evidence. |

## Known gap and next step

Repair or reconcile the unrelated `SessionSummary.skill_loads` change in the dirty worktree, then rerun the focused Task Board tests, `cargo test --workspace`, `cargo tauri build --no-bundle`, and a native Task-tab inspection. The native inspection should verify active, pending, archived, scheduled, and empty states with sanitized fixtures or a safe local snapshot.

No commit, merge, reset, or overwrite was performed.
