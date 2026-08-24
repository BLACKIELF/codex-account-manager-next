# Codex Account Manager Next 0824v1

[中文](README.md) | **English**

A local-first macOS control center for Codex accounts, quota, tasks, and local usage. Next preserves the original account manager, menu bar, quota, task, token/cost, inference-performance, AI-leadership, palette, updater, and Windows sources while adding strict low-quota switching and Feishu notifications.

> This is an unofficial project. Automatic switching replaces the active `~/.codex/auth.json` and restarts Codex. Both automation features are disabled by default and require explicit opt-in.

## Automatic switching below 10%

A switch is allowed only when every guard passes:

- An official 5-hour or 7-day window is strictly below `10%`; exactly `10%` does not trigger.
- The live task connection is online and at most 45 seconds old, with no running or waiting-for-input realtime task.
- Codex has been out of the foreground for at least two minutes, and the legacy account manager is not running.
- Each candidate is verified in realtime through its own `CODEX_HOME`, and has at least `30%` remaining in every triggering window.
- The cross-process lock, source credential recheck, and cooldowns pass. Failures retry no sooner than one hour; successful switches cool down for 30 minutes.

Manual and automatic switches share one safety path: email plus stable `chatgpt_account_id` binding, a cross-process lock, graceful Codex termination, a `0600` crash-recovery journal, atomic credential write, identity verification, and relaunch. Failure restores the original credential only while the transaction still owns the target state; a newer external credential is preserved and reported. Account switching never force-kills Codex.

## Feishu notifications

- The webhook is stored only in macOS Keychain. It is never prefilled into UI, project state, or logs.
- Only `https://open.feishu.cn/open-apis/bot/v2/hook/...` and `https://open.larksuite.com/open-apis/bot/v2/hook/...` are accepted. Redirects are rejected.
- Cards contain only a masked account label, triggering window, remaining quota, outcome, and timestamp.
- Notification failure does not alter the account-switch result. A test card is sent only after an explicit user click.

## Preserved features

- Saved-account cards, login/re-login, ordering, notes, deletion, and manual Switch & Open.
- Official Codex app-server identity, 5-hour/7-day/monthly quota, reset credits, and expiry data.
- Menu-bar quota rings, main window, status density, optional global shortcut, light/dark palettes, and accessibility basics.
- Today tasks, automations, session opening, and local Codex token, cost, trend, project, and Skill statistics.
- Local inference performance and AI leadership views; CC Switch remains read-only.
- Warm-up is now a one-shot schedule after an explicit manual refresh, with no automatic retry after startup, wake, or failure.
- Existing macOS release tooling and the Windows Tauri workspace remain in the repository.

## Isolation from the legacy app

- Bundle ID: `com.blackielf.codex-account-manager-next`
- Executable: `CodexAccountManagerNext`
- Saved profiles: `~/.codex-account-manager-next/profiles/`
- App data: `~/Library/Application Support/CodexAccountManagerNext/`
- Cache: `~/Library/Caches/CodexAccountManagerNext/`
- The global shortcut is disabled by default to avoid registration conflicts.

The development copy neither overwrites nor starts the legacy app. A real manual or automatic switch necessarily changes Codex's shared active login. Next repeats legacy-process checks, compares the current credential immediately before writing, and serializes its own switches; the legacy app does not share that lock, so zero race across both versions is not guaranteed.

## Build and pure local checks

Requires macOS 13+, Codex CLI, and Xcode Command Line Tools. Building does not install or launch the app:

```bash
make build
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-automatic-account-switch
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-switch-safety
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-feishu-webhook
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-automation-audit
```

The release artifact is named `CodexAccountManagerNext-8.24.1-mac-arm64.dmg`. `make run`, `make probe`, a real account switch, and a real Feishu send access local or external state and must be invoked explicitly in a trusted environment.

## Version and provenance

- Release: `0824v1`
- Bundle version: `8.24.1 (1)`
- Direct baseline: the current working tree of Codex Account Manager 0818v1
- Upstream: a SwiftUI project derived from [codexU](https://github.com/shanggqm/codexU)
- Reference research: [docs/REFERENCE_IMPLEMENTATIONS.md](docs/REFERENCE_IMPLEMENTATIONS.md)
- License: [MIT](LICENSE)
