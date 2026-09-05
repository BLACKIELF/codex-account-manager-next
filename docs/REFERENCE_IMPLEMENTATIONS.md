# Next 实现与第三方边界

Next 的当前产品结构、交互与发布渠道独立维护。代码来源、开源许可证和产品关联是不同问题。适用的来源与完整许可保留在 [THIRD_PARTY_NOTICES](../Resources/THIRD_PARTY_NOTICES.txt) 及各资源包许可证中。

## 当前实现

- 工作台与设置使用 SwiftUI/AppKit，沿用项目的 Domain、Providers、Services 和 UI 分层。
- 隔离账号、执行偏好、Hub 状态与启动门禁由 Next 自己的服务组合负责，不向外部账号管理器转发控制操作。
- 暖号使用有界的 Foundation 网络会话与最小 SSE 请求。相关参考协议的 MIT 声明随包保留。
- 安全切换使用现有身份校验、文件锁、原子写入与回滚事务。
- 飞书只允许显式配置的官方 Bot Webhook，凭据存于 Keychain，通知字段按既有脱敏模型发送。

## 维护原则

不以品牌重命名为理由删除代码版权，不把历史目录名当成运行时依赖，也不声称整个项目从零原创。历史调研的热度数字与旧版产品架构不作为当前选型或功能证据。具体公开能力以 [README](../README.md) 与 [架构](../BLUEPRINT.md) 为准。
