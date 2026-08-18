# Codex Account Manager 0818v1

[中文](README.md) | **English**

A local-first macOS utility for managing multiple Codex accounts and monitoring quota. It is derived from the SwiftUI shell of [codexU v1.3.0](https://github.com/shanggqm/codexU).

## Highlights

- Each saved account has an isolated `CODEX_HOME`. The active Codex login keeps using `~/.codex`; other accounts live under `~/.codexu/p/<short-id>`.
- Official `codex app-server` responses provide account identity, 5-hour/7-day remaining quota, and reset times. Identity mismatches are rejected to prevent quota data crossing accounts.
- The menu bar panel follows the current default Codex login. Account order, notes, re-login, and independent login are managed locally.
- “Switch & Open” first preserves the current login, runs the official `codex logout`, installs verified local credentials, and activates the existing Codex app without intentionally terminating its running process.
- Every remaining-quota indicator uses the same health thresholds: blue for `55–100%`, yellow for `25–54%`, and red for `0–24%`.
- Includes light and dark Liquid Keycap palettes with adjustable glass transparency.
- CC Switch access is read-only. Its local historical token number is a machine-wide estimate, not an official bill or account attribution.

## Switching and security boundaries

Account switching only reads and writes local `auth.json` files. The target identity must match the saved account card. Writes are atomic with `0600` permissions, and the previous file is restored on failure. Credential contents are never displayed, logged, or committed to GitHub.

On the first switch, the current default login is preserved in an isolated directory before `~/.codex/auth.json` is updated. The default `CODEX_HOME` remains unchanged, so the local Codex project and conversation index stays in the same data directory. A future change to official logout or server token policy may still require re-authentication.

When enabled by the user, automatic warm-up sends a minimal request through official Codex and consumes account quota. Its policy avoids low remaining quota, expired subscriptions, and duplicate runs.

See [SECURITY.md](SECURITY.md) for the complete local-data and network boundaries.

## Data semantics

- **Official quota:** returned by Codex app-server running against the corresponding `CODEX_HOME`.
- **Current account:** the identity verified from the default `~/.codex/auth.json`; the menu panel automatically selects the matching saved card.
- **Local historical tokens:** read from local Codex data and optionally from the read-only `~/.cc-switch/cc-switch.db`; they are not an official invoice.

## Build and verify

Requires macOS 13+, Codex CLI, and Xcode Command Line Tools.

```bash
make build
make test-profile-store
make test-cc-switch
build/CodexAccountManager.app/Contents/MacOS/CodexAccountManager --self-test-status-item
```

Run the local build:

```bash
open -n build/CodexAccountManager.app
```

These commands do not overwrite an app in `/Applications`. `make probe` reads local data and prints diagnostic JSON to the terminal; use it only in a trusted environment.

## Version and provenance

- Release name: `0818v1`
- Bundle version: `8.18.1 (1)`
- Derived from: codexU v1.3.0
- License: MIT; see [LICENSE](LICENSE)

This is an unofficial project and is not affiliated with OpenAI.
