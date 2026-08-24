# Codex Account Manager Next 0824v1 — handoff

## Authority

This repository is the isolated Next line. The direct baseline is the current Codex Account Manager 0818v1 working tree; inherited macOS features, resources, release tooling, and the Windows workspace were retained.

## Implemented

- strict official quota trigger at `< 10%` for 5-hour and 7-day windows;
- realtime candidate identity/quota validation with `>= 30%` in every triggered window;
- fail-closed live-task, foreground-idle, legacy-manager, cooldown, and Next-private cross-process lock gates;
- stable email + `chatgpt_account_id` binding through source, candidate, write, and post-restart checks;
- shared manual/automatic switch path with graceful Codex exit, private pending journal, atomic credential write, compare-and-swap recovery, and reopen attempt;
- optional Keychain-backed, host-allowlisted, no-redirect Feishu cards containing masked switch facts only;
- bounded local automation audit history and native SwiftUI automation center;
- isolated bundle, executable, support/cache/profile/defaults/update namespaces and disabled-by-default global shortcut;
- one-shot manual warm-up scheduling with no startup/wake/failure retry loop;
- inherited parser, aggregation, identity, de-duplication, and overflow fixes.

## Verified without starting the App

```bash
make build
codesign --verify --deep --strict build/CodexAccountManagerNext.app
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-automatic-account-switch
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-switch-safety
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-feishu-webhook
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-automation-audit
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-profile-store
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-cc-switch
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-app-server-pipe
```

The final build, codesign verification, and 20 non-UI self-tests passed on 2026-08-24, including the listed account, journal, Feishu, task, quota, parser, performance, and audit checks. Status-item and particle host-view tests reach AppKit registration and abort in this execution environment because no WindowServer session is available; they were not counted as product failures or claimed as passed. No App launch, login, Keychain write, real account switch, real Feishu request, installation, or modification of the legacy App was performed.

## Remaining runtime acceptance

Run only with test accounts and an approved test webhook:

1. install or open the Next build separately; confirm it refuses while the legacy manager is already running, while recognizing that the legacy app does not share Next's lock and therefore cross-version zero-race is not guaranteed;
2. verify manual success and forced rollback while Codex has no active task;
3. feed a real official `< 10%` source and `>= 30%` candidate, then confirm one switch and one masked Feishu card;
4. confirm exact `10%`, disconnected/stale task state, foreground Codex, waiting-input/running tasks, and candidate identity mismatch all block;
5. exercise VoiceOver, keyboard focus, Reduce Motion, light/dark mode, and narrow/wide window layouts.

Do not treat compile/self-tests as proof of those real end-to-end behaviors.

## Recovery

- automation and Feishu are disabled by default;
- disable automatic switching in the automation center before investigating any unexpected behavior;
- the original credential and target fingerprint are kept in a private `0600` pending journal until post-restart identity succeeds;
- startup recovery restores only while the shared auth still matches this transaction; newer external auth is preserved;
- persistent Next state is isolated under the paths documented in `README.md` and can be archived separately from the legacy manager.
