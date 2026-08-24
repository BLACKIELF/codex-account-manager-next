# Codex Account Manager Next 8.24.1

Release name: `0824v1`

## Highlights

- Opt-in automatic account switching below 10% with realtime source/candidate identity, quota, task, foreground, lock, and cooldown gates.
- Keychain-backed, allowlisted, no-redirect Feishu result cards containing masked event data only.
- Isolated macOS and Windows product namespaces while preserving the inherited feature set and sources.
- Verified credential write, graceful Codex restart, post-restart identity confirmation, and owned rollback with external-change preservation.

## Runtime acceptance boundary

Source build and pure self-tests do not perform a real login, switch, Keychain write, Feishu request, installation, or App launch. Complete those checks with dedicated test accounts before producing a public binary release.

## Checksums

- arm64: `SHA256_PLACEHOLDER`
- x86_64: `SHA256_PLACEHOLDER`

The release gate intentionally blocks while these placeholders remain.
