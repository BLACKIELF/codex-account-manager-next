# Distribution

Codex Account Manager Next supports macOS 13+ on Apple Silicon and Intel. The inherited Windows 10/11 x86_64 Tauri workspace is retained with a distinct product name, installer filename, cache directory, and application identifier so it cannot overwrite the legacy Windows App.

## Local macOS package

```bash
make release-arm64 VERSION=8.24.1
make release-intel VERSION=8.24.1
```

Artifacts:

```text
dist/CodexAccountManagerNext-8.24.1-mac-arm64.dmg
dist/CodexAccountManagerNext-8.24.1-mac-x86_64.dmg
```

Default builds are ad-hoc signed. Public distribution should use a Developer ID Application certificate, notarization, and checksum verification. The updater only opens a matching browser release page or asset; it never silently downloads or replaces the App.

## Release gates

```bash
make memory-risk-check
make release-package VERSION=8.24.1
make release-cross-platform-check VERSION=8.24.1
```

`release-package` builds both macOS architectures and runs the pure self-tests, including automatic-switch policy, switch safety, Feishu serialization, audit storage, profile storage, app-server pipe, quota, rendering, and update checks. It does not perform a real login, account switch, or Feishu send.

The tag-triggered GitHub workflow builds macOS and Windows artifacts but does not create a GitHub Release. Tags, release creation, signing credentials, and notarization remain explicit external actions.

## Windows

On a Windows runner with Rust, Node.js, npm, and the MSVC toolchain:

```powershell
.\scripts\build-windows-release.ps1 -Version 8.24.1
```

The Windows implementation is inherited and does not yet expose the new macOS automatic-switch/Feishu control center. Do not claim cross-platform parity for those two features until they are implemented and verified on Windows.

Windows artifacts are named `CodexAccountManagerNext-8.24.1-windows-x86_64.*`.
