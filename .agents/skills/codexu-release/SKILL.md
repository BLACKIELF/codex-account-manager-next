---
name: codexu-release
description: Codex Account Manager Next release SOP for packaging macOS and Windows artifacts, validating checksums and metadata, and, when explicitly authorized, tagging, pushing, or publishing a GitHub Release.
---

# Codex Account Manager Next Release SOP

## Scope

Run this skill from the repository root. Keep the internal skill ID and folder name `codexu-release` for compatibility; all user-facing release names and artifacts use Codex Account Manager Next.

Repository upload, tag creation, GitHub Release creation, and binary publication are separate external actions. Perform only the actions the user explicitly authorized. Before any authorized publish, verify the current remote state, keep unrelated user changes out of release commits, and report exactly what was built, pushed, and released.

Do not trust a remembered "latest" version. Always confirm the current tag and release state with GitHub before choosing the next version.

## Preflight

1. Inspect the worktree and branch:

```sh
git status --short
git branch --show-current
git remote -v
```

If unrelated files are dirty, do not stage or revert them. Either keep the release scoped to known release files or ask before mixing them into the release commit.

2. Confirm GitHub access and current releases:

```sh
gh --version
gh auth status
gh repo view --json nameWithOwner,url
gh release list --limit 10
git fetch origin --tags
```

3. Verify that the target `v<version>` tag and GitHub Release do not already exist unless the task is explicitly to repair or replace them.

## Mandatory Global Memory-Risk Gate

Run this gate before changing release metadata, packaging, committing, tagging, pushing, or creating a GitHub Release:

```sh
make memory-risk-check
sed -n '1,240p' build/memory-risk/report.md
```

The scan covers the entire production source tree, not only the release diff. Treat any non-zero exit as a hard release blocker. There is no override flag: fix or explicitly bound the risky lifecycle before continuing.

Do not accept the PASS line without reviewing the generated global inventory. Inspect every reported risk category and the related release diff, with particular attention to:

- `Process` and `Pipe`: bounded stdout reads with partial-response semantics for long-lived pipes, drained or redirected stderr, EOF handling, timeout, termination, and forced cleanup.
- `Timer`, notification/KVO observers, event monitors, and Combine subscriptions: weak captures and matching invalidation/removal/cancellation.
- buffers, caches, samples, pending request maps, and static mutable collections: byte/count limits, eviction, timeout, and working-set release.
- `Data(contentsOf:)` and transcript/session readers: trusted input boundaries, file-size checks, streaming behavior, and oversized-record handling.
- recursive and parent-path traversal: explicit root/base termination, visited-node/path cycle guards, and regression coverage for platform-specific Foundation behavior.

If a reviewer finds a plausible unbounded growth path that the script does not catch, stop the release, fix the risk, and extend `scripts/check-memory-risks.sh` so the same class of regression becomes automatically blocking.

`make release-package` and `make release-check` rerun this gate. Do not bypass the repository wrappers by calling packaging scripts or lower-level release targets directly.

## Versioning

Use these conventions unless the user specifies otherwise:

- Version string: `<major>.<minor>.<patch>` or `<major>.<minor>.<patch>-betaNN`.
- Git tag: `v<version>`.
- Formal release name: `MMDDvN`, stored in `CodexAccountManagerNextReleaseName`.
- Release title: `Codex Account Manager Next v<version>`.
- Release commit: `chore(release): prepare v<version>`.
- Beta releases use `gh release create --prerelease`.

Update `Resources/Info.plist`:

- `CFBundleShortVersionString` to `<version>`.
- `CFBundleVersion` to the next build number.
- `CodexAccountManagerNextReleaseName` to the approved `MMDDvN` name.

Validate the plist after editing:

```sh
plutil -lint Resources/Info.plist
plutil -p Resources/Info.plist | rg "CFBundleShortVersionString|CFBundleVersion|CodexAccountManagerNextReleaseName" -C 2
```

## Documentation Updates

Update only the release-relevant files unless the user asks for broader docs:

- `CHANGELOG.md`: add the new release section and date.
- `README.md`: update current version, download links, and visible release notes in Chinese.
- `README.en.md`: update current version, download links, and visible release notes in English.
- `docs/release-notes-*.md`: keep the complete local release record used by `make release-check`, including verification, assets, checksums, and the actual signing/notarization status.

Use the current Next release-note contract: title, `Release name: MMDDvN`, a non-empty `## Highlights` section, runtime acceptance boundaries, and checksums. `## 主要更新` remains accepted for a Chinese release note. Only the complete Highlights/主要更新 section is published in the GitHub Release body. Leave checksum placeholders until after packaging, then fill them with actual SHA-256 values.

Run:

```sh
git diff --check
```

## Package

Run the deterministic repository wrapper:

```sh
make release-package
```

It reruns the global memory-risk gate, runs the self-tests, builds both architectures, checks the DMGs and checksums, mounts both images, verifies Mach-O architecture, and verifies codesign. Do not manually repeat those steps unless debugging the wrapper.

Expect these assets for `<version>`:

```text
dist/CodexAccountManagerNext-<version>-mac-arm64.dmg
dist/CodexAccountManagerNext-<version>-mac-arm64.dmg.sha256
dist/CodexAccountManagerNext-<version>-mac-x86_64.dmg
dist/CodexAccountManagerNext-<version>-mac-x86_64.dmg.sha256
```

Verify checksums and copy the values into release notes:

```sh
cat dist/CodexAccountManagerNext-<version>-mac-arm64.dmg.sha256
cat dist/CodexAccountManagerNext-<version>-mac-x86_64.dmg.sha256
```

After filling the macOS checksums, run the macOS metadata gate:

```sh
make release-check
```

Do not create a release tag until this command passes. This gate does not build Windows installers.

Build Windows from a pinned checkout on a Windows runner:

```powershell
.\scripts\build-windows-release.ps1 -Version <version>
```

The script requires the committed `windows/Cargo.lock` and frontend `package-lock.json`, uses `cargo test --locked` and `npm ci`, runs the Windows web contract tests/build, and produces:

```text
dist/windows/CodexAccountManagerNext-<version>-windows-x86_64.msi
dist/windows/CodexAccountManagerNext-<version>-windows-x86_64.msi.sha256
dist/windows/CodexAccountManagerNext-<version>-windows-x86_64-setup.exe
dist/windows/CodexAccountManagerNext-<version>-windows-x86_64-setup.exe.sha256
```

After collecting both platform outputs under `dist/`, run:

```sh
make release-cross-platform-check VERSION=<version>
```

Treat this cross-platform checksum gate as mandatory before publishing binaries. The tag-triggered workflow builds and verifies packages but does not itself create a GitHub Release.

Do not claim Apple notarization unless a notarization step was actually run. The current Makefile release flow uses the signing behavior configured in the repository.

## Prepare GitHub Release Body

Generate the concise GitHub Release body from the complete local release notes before committing, tagging, or pushing:

```sh
.agents/skills/codexu-release/scripts/make-github-release-body.sh \
  docs/release-notes-<notes>.md \
  build/github-release-body-v<version>.md
sed -n '1,160p' build/github-release-body-v<version>.md
```

The generated body must contain only the complete `## Highlights` or `## 主要更新` section. Do not publish the release-note title, release name, verification details, asset list, checksums, signing/notarization text, or any later section. Keep those details in the tracked release notes for local validation and auditability. Treat a generation error or unexpected excerpt as a release blocker.

## Commit, Tag, And Push

Stage release metadata and documentation, not generated DMGs unless repository policy changes:

```sh
git add Resources/Info.plist CHANGELOG.md README.md README.en.md docs/release-notes-*.md
git status --short
git commit -m "chore(release): prepare v<version>"
```

Before pushing, fetch and inspect divergence:

```sh
git fetch origin --tags
git log --oneline --left-right --cherry-pick origin/main...HEAD
```

If the remote contains the same logical commits with different hashes, rebase onto `origin/main`, then recreate any local tag that pointed to the pre-rebase commit:

```sh
git rebase origin/main
git tag -d v<version>  # only if the local tag points at the old commit
git tag -a v<version> -m "Codex Account Manager Next v<version>"
```

Do not force-push `main` or delete remote tags without explicit user approval. After the branch and tag are correct:

```sh
git push origin main
git push origin v<version>
```

## Create GitHub Release

Create the GitHub Release with the exact packaged assets and the generated concise body:

```sh
gh release create v<version> \
  dist/CodexAccountManagerNext-<version>-mac-arm64.dmg \
  dist/CodexAccountManagerNext-<version>-mac-arm64.dmg.sha256 \
  dist/CodexAccountManagerNext-<version>-mac-x86_64.dmg \
  dist/CodexAccountManagerNext-<version>-mac-x86_64.dmg.sha256 \
  dist/windows/CodexAccountManagerNext-<version>-windows-x86_64.msi \
  dist/windows/CodexAccountManagerNext-<version>-windows-x86_64.msi.sha256 \
  dist/windows/CodexAccountManagerNext-<version>-windows-x86_64-setup.exe \
  dist/windows/CodexAccountManagerNext-<version>-windows-x86_64-setup.exe.sha256 \
  --title "Codex Account Manager Next v<version>" \
  --notes-file build/github-release-body-v<version>.md \
  --prerelease
```

Omit `--prerelease` only for stable releases. If a release already exists, inspect it first and use `gh release edit` only when the user intends an update.

## Verify And Report

Verify the published release:

```sh
gh release view v<version> --json tagName,name,body,isPrerelease,isDraft,url,assets,publishedAt,targetCommitish
gh release view v<version> --json body --jq .body > build/published-github-release-body-v<version>.md
diff -u build/github-release-body-v<version>.md build/published-github-release-body-v<version>.md
git status --short
```

Confirm that the published `body` matches the generated file and contains exactly one `## Highlights` or `## 主要更新` section.

Some `gh` versions do not support `isLatest`; remove unsupported JSON fields rather than treating that as a release failure.

Report these facts to the user:

- Version, build number, tag, and release URL.
- Commit hash pushed to `main`.
- Uploaded asset names and SHA-256 values.
- Validation/build commands that ran.
- Any limitation, such as ad-hoc signing or no notarization.

## Recovery Notes

- Push rejected: run `git fetch origin`, inspect divergence with `git log --left-right --cherry-pick`, rebase if the remote has equivalent commits, recreate the local tag if needed, then push again.
- Local stale tag: delete and recreate only the local tag after confirming it points to an old pre-rebase commit.
- Remote tag or release conflict: stop and inspect with `git ls-remote --tags origin v<version>` and `gh release view v<version>`. Do not overwrite remote state without explicit user approval.
- Build failure: fix the underlying source or packaging issue, rerun `make release-package` and the Windows packaging workflow, then rerun the cross-platform checksum gate before publishing.
- Memory-risk gate failure: stop before versioning or packaging, inspect `build/memory-risk/report.md`, fix the unbounded lifecycle, extend the gate when needed, and rerun `make memory-risk-check`. Never suppress or bypass the failure.
