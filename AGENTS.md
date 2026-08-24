# Project rules

- Preserve all inherited user-facing features unless the task explicitly removes one.
- Keep Next isolated: bundle, executable, profiles, support, cache, defaults, hotkey, update source, logs, and temporary files must not reuse legacy namespaces.
- Never log, render, fixture, or commit auth tokens, webhook URLs, raw account email, prompt/response bodies, or private local paths.
- Manual and automatic switching must share the same identity, lock, graceful-exit, atomic-write, verification, rollback, and recovery path.
- Automation stays opt-in and fail-closed. Missing/stale task, identity, quota, Keychain, or process evidence blocks mutation.
- Feishu cards may contain only the masked DTO defined by the service; webhook hosts and paths stay allowlisted and redirects stay disabled.
- Use native SwiftUI/AppKit and existing helpers before adding dependencies or abstractions.
- Before publication: inspect the staged diff, run the pure self-tests, scan staged content for secrets/private paths, and state which runtime behaviors were not exercised.
- Never install, launch, login, switch a real account, send a real notification, tag, release, or push unless the user explicitly authorizes that action.
