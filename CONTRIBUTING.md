# Contributing

Build without launching the App:

```bash
make build
make test-palettes
./scripts/test-status-item.sh
```

For account automation changes, also run:

```bash
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-automatic-account-switch
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-switch-safety
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-feishu-webhook
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-automation-audit
```

Keep changes focused, preserve the local-first boundary, and update documentation when behavior, permissions, storage, packaging, or network disclosure changes. Never attach real account data, webhooks, thread titles, local databases, or screenshots containing private tasks to an issue or pull request.

Windows runtime captures and probe output must remain under the Git-ignored `.local-artifacts/` directory. Any public visual evidence must be regenerated from fully synthetic fixtures under the rules in [`docs/windows-port/README.md`](docs/windows-port/README.md).

Palette packages remain declarative under `Resources/Palettes/<stable-id>/` and must pass `make test-palettes`. Historical palette IDs, project-local tool IDs and Windows package paths remain internal compatibility details, not current product names. Public product copy, issue routing and releases use Next.
