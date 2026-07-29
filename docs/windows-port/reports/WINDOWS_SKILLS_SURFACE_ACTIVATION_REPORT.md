# Windows Skills Surface Activation — Acceptance Report

**Date:** 2026-07-29
**Scope:** Focused Codex-only activation of the Windows Tauri Dashboard Skills tab.

## Verdict

**Accepted.** Automated checks and a fresh native UI check passed.

## What changed

- Activated the existing lower Dashboard **Skills** tab without adding a second navigation surface or changing Dashboard ownership.
- Replaced the placeholder with a local-read list that shows only a Skill name, a generic source label, observed session count, latest observation time, and local-read count.
- Added a focused `SkillsPanel` with an explicit no-observations state and privacy explanation.
- Implemented Codex transcript reduction for `function_call` and `custom_tool_call` records that reference a terminal `SKILL.md` filename.
- Bumped the transcript cache schema to invalidate prior summaries that do not carry the new safe observation records.

## Data and privacy boundary

The macOS reference counts local `SKILL.md` reads found in tool-call records, but retains a full filesystem path and derives static-file token/byte estimates. The Windows port intentionally does not copy those fields.

| Returned by the Windows dashboard contract | Deliberately excluded |
| --- | --- |
| Skill directory name | Full or relative private paths |
| Generic origin: Personal Codex, Project, Bundled Codex, or Local reference | Raw `arguments`, `input`, `cmd`, and `command` text |
| Exact observed local-read count | Prompts, responses, tool arguments, and source contents |
| Distinct local session count and last observation time | Static-file byte or token estimates |

The parser only examines local `function_call` / `custom_tool_call` values long enough to recognize a `SKILL.md` reference. It immediately reduces the record to safe metadata and persists no path or raw argument in the transcript cache or IPC model. Missing observations remain an explicit unavailable state, never a fabricated zero-usage claim.

## Evidence and regression coverage

| Check | Result |
| --- | --- |
| Failing web contract before implementation | Expected failure: the Dashboard still contained the Skills placeholder. |
| Failing Rust privacy regression | Expected source-label failure for repeated Windows separators; fixed by component-based path classification. |
| `node --test tests/dashboard-source-hierarchy.test.mjs tests/quota-overview-contract.test.mjs tests/leadership-rail-layout.test.mjs tests/skills-panel-contract.test.mjs` | Passed: 4/4. |
| `npm run build` | Passed. Vite emitted its pre-existing chunk-size advisory. |
| `cargo test -p codexu-core reduces_skill_reads_to_safe_local_usage_without_paths_or_arguments` | Passed: 1/1. |
| `cargo test --workspace` | Passed: 49 tests; 1 environment-dependent authenticated-Codex quota test remained intentionally ignored. |
| Isolated `cargo tauri build --no-bundle` | Produced and launched a fresh native executable from a temporary Cargo target. |
| `git diff --check` | Passed. |

## Native UI acceptance

The shared release executable was locked by two already-running `codexu-tauri` instances. To preserve their state, the fresh build used an isolated temporary Cargo target. The newly built native app opened successfully; the existing lower Skills tab was selectable and showed the real local no-observations state with its privacy explanation. The live DOM exposed no path, raw argument, prompt, or source-content field in that surface. No native screenshot was retained because unrelated task content visible elsewhere in the app is private.

## Known limits

- A `SKILL.md` reference is evidence of a local read, not proof that a Skill completed successfully; the UI labels it as a local read.
- The surface intentionally does not infer token impact, task outcome, or other statistics not present in the local observation.
- The live snapshot contained no observable Skill reads, so populated-row visual acceptance is covered by the Rust privacy regression and web contract test rather than fabricated live data.
- No commits, merges, resets, or publishing actions were performed. Existing unrelated dirty work was preserved.
