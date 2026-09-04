# Security Policy

Only the latest default-branch version is supported. Report vulnerabilities through a private GitHub Security Advisory when they include credentials, account identifiers, local paths, thread data, or webhook information.

## Local trust boundary

Codex Account Manager Next may read:

- `~/.codex/auth.json` and saved-profile `auth.json` files for identity validation and account switching.
- responses from the locally installed `codex app-server` for identity, quota, and task state.
- local Codex metadata used by retained usage, task, performance, and leadership views.
- optional `~/.cc-switch/cc-switch.db` in read-only mode.
- isolated state under `~/.codex-account-manager-next`, Application Support, Caches, and UserDefaults.

Credential values must never be displayed, logged, emitted by diagnostics, included in Feishu cards, or committed. Saved credentials and account-switch locks use restrictive local permissions.

Local analytics and session caches may retain project, Skill, and rollout source paths for record grouping. Those path fields are not uploaded, and known full paths are omitted from the diagnostics JSON and analytics UI. Do not attach those caches to a public report.

The active Codex login is inherently shared at `~/.codex/auth.json`. Low-quota automation emits a candidate hint from fresh local source evidence plus saved candidate metadata, writes a local audit event, and may send an optional masked Feishu notification; it exposes no launch or switch action and never rewrites the shared login. The user must return to the account card, whose terminal entry applies the Hub gate. Explicit Desktop switching is a separate action and refuses to proceed when its safety checks cannot verify the source and target state. System-profile re-authentication and recovery of an unfinished switch may also update the shared login through their guarded paths. Legacy-process checks are repeated around a manual write, but the legacy manager does not participate in the Next lock protocol.

## Network boundary

Network access is limited to explicit product functions:

- the installed Codex CLI and `codex app-server` communicate with OpenAI services for login, identity, quota, and tasks; user-enabled warm-up sends a minimal request directly to the ChatGPT Codex backend endpoint;
- official profile metadata may be requested from `https://chatgpt.com/backend-api/wham/profiles/me` using the selected local account;
- the updater reads public metadata from `https://api.github.com/repos/BLACKIELF/codex-account-manager-next/releases` and never installs silently;
- optional Feishu notifications send masked account information and non-sensitive event metadata to an allowlisted HTTPS webhook on `open.feishu.cn` or `open.larksuite.com`, without redirects.

Feishu is a user-enabled third-party disclosure boundary. Notification failure never changes local account or quota state. Standard transport metadata such as IP address, TLS information, User-Agent, and request time remains visible to the contacted service.

Automatic Feishu cards require the notification toggle. Once a valid webhook is stored, the explicit Send Test button can send one test card even while automatic notifications are disabled.

## Account-switch guarantees

- target email and stable `chatgpt_account_id` must match the saved profile, and conflicting token/account claims are rejected;
- a Next-private cross-process lock serializes manual switches initiated by Next;
- Codex receives a graceful termination request first; after a timeout the app or a remaining shared runtime may be force-terminated, and the write is aborted if shutdown still fails;
- source credentials are compared with the previously captured state immediately before an atomic `0600` write;
- before that write, a private `0600` pending-switch journal records the original state and target fingerprint; startup recovery uses compare-and-swap and never overwrites a newer external credential;
- the write is verified; on a later failure, Next restores the original credential only while it still owns the target state, and otherwise preserves the external program's newer state and reports that rollback was incomplete;

The legacy manager does not acquire the Next-private lock. Repeated legacy-process checks plus credential compare-and-swap reduce the race window, but cannot guarantee zero race when both versions run concurrently. Do not switch accounts from both managers at the same time. These guards reduce local race and corruption risk; they do not make third-party account automation officially supported by OpenAI.
