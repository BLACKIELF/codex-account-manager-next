# 安全说明 / Security Policy

## 支持版本 / Supported Versions

The latest version on the default branch is the supported version.

## 报告漏洞 / Reporting a Vulnerability

Please report security issues privately instead of opening a public issue when the report includes account data, local file paths, thread titles, local Codex database contents, or other sensitive information.

Include:

- macOS version.
- Codex Account Manager version.
- Whether the issue affects app launch, local file reads, quota reads, packaging, or update distribution.
- Minimal reproduction steps without private Codex data.

## 本地数据范围 / Local Data Scope

Codex Account Manager may read:

- `~/.codex/auth.json` and saved-profile `auth.json` files for local identity verification and user-requested switching.
- local responses from `codex app-server` for quota and account identity.
- local Codex SQLite/rollout metadata used by retained token statistics. Prompt and response bodies must not be persisted by account-manager features.
- optional `~/.cc-switch/cc-switch.db` in read-only mode for machine-wide historical token estimates.
- local app settings and account snapshots under Application Support.

Saved credentials must remain local, use restrictive filesystem permissions, and must never be displayed, logged, included in diagnostics, or committed to the repository. Local usage, account, thread, prompt, response, and path data must not be uploaded to third parties.

## 网络范围 / Network Scope

The app is local-first, but official Codex operations require network access:

- `codex app-server`, `codex login`, `codex logout`, and user-enabled warm-up use the installed Codex CLI and official OpenAI services.
- Official profile metadata is requested from `https://chatgpt.com/backend-api/wham/profiles/me` with the selected local account credential.
- The update checker may request public release metadata from `https://api.github.com/repos/BLACKIELF/codex-account-manager/releases`.

Update requests must not include local usage, credentials, account data, threads, paths, prompts, or responses. Standard HTTPS headers such as `User-Agent` and `If-None-Match` may be sent.

The updater must not silently download, install, replace, or relaunch the app. It may open the default browser to a matching release asset or release page.
