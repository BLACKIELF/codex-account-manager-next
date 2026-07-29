# Windows Official Quota Activation Report

**Date:** 2026-07-29
**Scope:** Windows Tauri Codex dashboard quota activation

## Verdict

The Windows Dashboard now activates official Codex quota when the locally installed, authenticated Codex CLI returns a valid rate-limit response. This machine's live response contained a single seven-day window; it is accepted and rendered as an official quota instead of being labelled unavailable because a five-hour window is absent.

The feature never derives quota from session JSONL, local token totals, or transcript content. It starts in a neutral **Checking official quota** state, offers a retry action, and retains the last verified official window as **last verified** if a later refresh fails.

## Implemented boundary

| Concern | Implementation | Result |
| --- | --- | --- |
| macOS reference | Mirrors the macOS app-server contract: initialize, account read, then rate-limit read. | Same official source and known-window semantics. |
| Windows transport | Starts the already-installed `codex app-server` on a private loopback WebSocket, then shuts down that child process. | No third-party service or uploaded data. |
| Official data | Prefers `rateLimitsByLimitId.codex`, then `rateLimits`; reads `usedPercent`, `windowDurationMins`, and `resetsAt`. | Official values retain their source meaning. |
| Window topology | Accepts any non-empty combination of 5-hour, 7-day, and monthly windows. Unknown, malformed, or duplicate windows fail closed. | A weekly-only account is usable; missing windows are never fabricated. |
| Continuity | A fresh official read is `available`; later failures preserve the last verified official windows as `stale`. | No false zero or false unavailable state after a transient failure. |
| UI | The Dashboard status chip says `Official quota active`, `Official quota last verified`, or `Checking official quota`; the quota card shows every returned official window. | The quota state is visible and retryable. |

## Evidence

- `cargo test --workspace`: 35 core unit tests, 2 quota parser/protocol tests, 2 quota dashboard-continuity tests, and 7 Tauri state tests passed; the live test is intentionally excluded from the default suite.
- `cargo test -p codexu-core --test codex_app_server_quota -- --ignored`: the locally installed, authenticated Codex app-server returned at least one authoritative quota window.
- Web contract tests: 3 passed, including weekly-only rendering and retry-state coverage.
- `npm run build`: passed.
- `cargo tauri build --no-bundle`: passed and produced `windows/target/release/codexu-tauri.exe`.
- `git diff --check`: passed.
- Native release check: after closing two verified stale `codexU` processes, the single current release window showed `Official quota active` and one seven-day official window. No screenshot or quota value is retained in this report.

## Privacy and failure behavior

The reader calls only read-oriented app-server methods and communicates over `127.0.0.1` for the duration of the refresh. It does not log or expose the account identifier, quota values, session text, paths, prompts, or tool arguments. The report intentionally omits this machine's quota numbers.

If the installed CLI is missing, not authenticated, does not return a recognized rate-limit topology, or cannot be reached, the first render remains neutral and lets the user retry. A successful value is not converted into an estimate or zero during a later read failure.

## Native acceptance note

Two stale processes were identified by exact executable path and closed: one release from the historical Dashboard worktree and one stuck `--dump-json` debug process. The freshly built current release was then the only `codexU` window. Native inspection confirmed its `Official quota active` status and the single seven-day official quota card. The visual capture is deliberately not embedded or stored because it contains private local usage data.

## Known limits

- OpenAI Support stated on 2026-07-13 that the five-hour **display** was temporarily removed as an incident response and that weekly reset information would remain visible. The app therefore treats an absent 5-hour window as absent official display data: it neither invents one nor claims the underlying enforcement has been permanently removed.
- The service may legitimately return only one official limit window; the product does not promise a five-hour or monthly window when the account does not provide one.
- Last-verified quota is held in the application snapshot for refresh continuity; it is not written as a separate persistent quota cache.
- This change activates Codex quota only. It does not enable an additional runtime or change the local-token and Leadership data boundaries.
