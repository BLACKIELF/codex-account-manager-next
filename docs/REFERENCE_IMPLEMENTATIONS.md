# Reference implementations

Checked on 2026-08-24. These projects informed mechanisms and threat modeling; no dependency or source file was copied into Next.

| Project | Snapshot | What was adopted | Boundary |
|---|---:|---|---|
| [shanggqm/codexU](https://github.com/shanggqm/codexU) | 331 stars, MIT | Existing SwiftUI shell, menu bar, local usage, task, palette, update, and Windows foundations | Direct upstream lineage; Next preserves attribution and MIT license |
| [Loongphy/codex-auth](https://github.com/Loongphy/codex-auth) | 2,531 stars, MIT | Realtime per-account validation as a product requirement | Implemented independently through this project's existing Codex app-server reader |
| [steipete/CodexBar](https://github.com/steipete/CodexBar) | 20,487 stars, MIT | Same-origin HTTPS thinking, explicit retry/cooldown policy, adaptive refresh discipline | Concepts only; no source copied and no new package added |
| [Lampese/codex-switcher](https://github.com/Lampese/codex-switcher) | 657 stars, license not declared | Multi-account switching and quota-routing threat model | Concepts only because repository licensing was not explicit |
| [777genius/claude-notifications-go](https://github.com/777genius/claude-notifications-go) | 792 stars, license not declared | Notification result separation and operational event shape | Concepts only; no source copied because licensing was not explicit |

Feishu webhook constraints follow the official [custom bot documentation](https://open.feishu.cn/document/client-docs/bot-v3/add-custom-bot): HTTPS webhook, explicit user configuration, bounded sanitized card fields, and independent delivery failure.

Next deliberately uses Foundation, Security.framework, SwiftUI/AppKit, POSIX file locking, and existing project services. No third-party runtime dependency was added for automatic switching or Feishu.
