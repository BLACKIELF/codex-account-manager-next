# codexU Windows 版本架构蓝图

## 一、系统架构图

![架构图](docs/windows-port/blueprint/diagram.png)

架构图源文件都在 [`docs/windows-port/blueprint/`](docs/windows-port/blueprint/)：

- [`schema.yaml`](docs/windows-port/blueprint/schema.yaml) —— **真值**
- [`diagram.svg`](docs/windows-port/blueprint/diagram.svg) —— 确定性 renderer 生成的可编辑主图
- [`diagram.png`](docs/windows-port/blueprint/diagram.png) —— 展示图
- [`diagram.html`](docs/windows-port/blueprint/diagram.html) —— 可选预览页
- [`diagram.mmd`](docs/windows-port/blueprint/diagram.mmd) —— Mermaid fallback

---

## 二、一句话定位

codexU Windows 版本是原 macOS 应用的 **Windows 移植版**。它保留 codexU 的核心架构与数据模型，只替换平台绑定层：用 Windows 系统托盘替代 macOS 菜单栏，用 WinUI 3 或 Tauri WebView 替代 SwiftUI/Cocoa，从而把 Codex / Claude Code 的额度、用量、任务与 AI 领导力评估带给 Windows 用户。

---

## 三、迁移原则

1. **核心 pipeline 不变**：Runtime Provider → MultiRuntimeUsageReader → Aggregator → Leadership Model。
2. **Domain 模型直接翻译**：`TokenBreakdown`、`UsageTrend`、`LeadershipReport` 等保持同名同义。
3. **平台绑定层重写**：托盘、主窗口、设置、打包、签名。
4. **本地优先、隐私优先不变**：不上传 usage、线程、路径、日志或账户数据。
5. **数据格式假设一致**：在 Windows 上复用相同的 JSONL / SQLite / TOML 解析逻辑，只改路径。

---

## 四、可复用 vs 需重写

| 模块 | macOS 实现 | Windows 方案 | 可复用度 |
|---|---|---|---|
| `LeadershipModel` / `LeadershipAggregator` | Swift struct + 算法 | 同构翻译 | **高** |
| `TokenBreakdown` / `PricedTokenUsage` | Swift struct | 同构翻译 | **高** |
| `ClaudeCodeRuntimeProvider` | 文件/JSONL/SQLite 解析 | 路径适配 + 解析逻辑复用 | **高** |
| `LeadershipDataReader` | fingerprint 缓存 + SQLite | 直接翻译 | **高** |
| `AgentUsageAggregator` | 聚合算法 | 直接翻译 | **高** |
| `RuntimeProviderRegistry` | 注册表 | 同构实现 | **高** |
| `Menu Bar Extra` | `NSStatusItem` + SwiftUI | Windows System Tray | **低（重写）** |
| `SwiftUI Views` | SwiftUI + Liquid Glass | WinUI 3 / Tauri WebView | **低（重写）** |
| `GlobalShortcut` | Carbon HIToolbox | Windows HotKey API | **低（重写）** |
| `Makefile` | swiftc + codesign + DMG | cargo / msbuild + MSI/MSIX | **低（重写）** |

---

## 五、推荐技术选型

### 首选：Rust + Tauri

- **理由**：
  - Rust 与 codexU "本地、快速、隐私" 气质一致。
  - Tauri v2 原生支持 Windows 系统托盘与菜单。
  - 核心算法可用 Rust crate 独立实现，单测友好。
  - 打包体积小，远小于 Electron。
  - 未来若需 Linux 版本，迁移成本最低。
- **风险**：Rust 学习曲线；Tauri Windows 深度视觉集成不如原生。

### 备选：C# + WinUI 3

- **理由**：
  - Windows 原生体验最好，NotifyIcon 最成熟。
  - C# 翻译 Swift struct 与算法效率高。
  - WinUI 3 支持 Mica/Acrylic，视觉现代。
- **风险**：锁定 Windows；未来无法复用。

### 不推荐：Electron

- 与 codexU "小而快" 的产品气质不符；打包体积大、内存占用高。

---

## 六、关键待调研问题

在实现前必须确认：

1. Windows 上 Codex CLI / 桌面应用的数据路径是什么？
2. Windows 上 Claude Code 的数据路径是什么？
3. `state_5.sqlite` 表结构是否与 macOS 一致？
4. JSONL 事件格式是否一致？
5. Windows 上是否有等价的 `codex app-server` 本地 API？
6. Claude Code statusLine snapshot 在 Windows 上如何生成？
7. Windows 上 JSONL 是否有 UTF-8 BOM 问题？

详见 [`RFC.md`](../RFC.md) 的"Windows 数据路径调研清单"。

---

## 七、分阶段实施建议

### 阶段 1：核心 Domain + 数据读取原型
- 翻译模型：`TokenBreakdown`、`DetailedUsage`、`UsageTrend`、`LocalUsage`。
- 翻译 `ClaudeCodeRuntimeProvider` 的 JSONL 解析与缓存。
- 翻译 `LeadershipDataReader` 的 SQLite 查询与 fingerprint 缓存。
- 适配 Windows 路径。
- **交付物**：命令行工具，输出与 macOS `--dump-json` 等价的 JSON。

### 阶段 2：聚合与评估
- 实现 `RuntimeProvider` trait。
- 实现 Codex provider、Claude Code provider。
- 复现 `MultiRuntimeUsageReader`、`AgentUsageAggregator`、`LeadershipAggregator`。
- **交付物**：核心库 + 单测。

### 阶段 3：Windows UI
- 系统托盘 + 弹出菜单。
- 主窗口：额度环、趋势图、任务板、AI 领导力。
- 设置窗口。
- **交付物**：可运行的 GUI 应用。

### 阶段 4：打包与发布
- MSI/MSIX/便携版。
- 自动更新。
- **交付物**：安装包 + GitHub Release。

---

## 八、协作方式建议

建议以 **独立 fork / 新项目** 形式存在，例如 `shanggqm/codexU-windows` 或社区 fork。原因：

- 原仓库是 macOS Swift/Cocoa 项目，硬塞 Windows 代码会破坏项目边界。
- 两个平台的前端、构建、发布链路完全不同，分开迭代更高效。
- 独立项目可以更快响应 Windows 用户需求。

下一步：向原仓库提交 RFC issue，说明 Windows port 计划，询问原作者倾向的协作方式。

---

## 九、相关文档

- [`../RFC.md`](../RFC.md) —— Windows 版本技术选型与迁移 RFC
- [`../../BLUEPRINT.md`](../../BLUEPRINT.md) —— macOS 版本完整架构蓝图
- [`../../docs/architecture/schema.yaml`](../../docs/architecture/schema.yaml) —— macOS 版本架构真值
