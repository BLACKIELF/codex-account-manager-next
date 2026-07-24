# codexU Windows 版本技术选型与迁移 RFC

> 状态：草案 / 待讨论  
> 关联 issue: [#7](https://github.com/shanggqm/codexU/issues/7)、[#31](https://github.com/shanggqm/codexU/issues/31)  
> 目标：在不改变核心架构的前提下，将 codexU 的能力迁移到 Windows 平台。  
> 数据路径调研：Phase 0 已完成（见 [`roadmap/phase-0-research/RESEARCH.md`](./roadmap/phase-0-research/RESEARCH.md)）

---

## 一、问题与目标

### 1.1 用户诉求

GitHub 上已有用户多次请求 Windows 版本：

- [#7: 增加 win 系统，球球了](https://github.com/shanggqm/codexU/issues/7)
- [#31: 可以做一个 Windows 版本的，嘛](https://github.com/shanggqm/codexU/issues/31)

### 1.2 核心目标

- **保留 codexU 的核心产品能力**：额度展示、token 用量、任务看板、AI 领导力评估。
- **保留核心架构与数据模型**：Runtime Provider → MultiRuntimeUsageReader → Aggregator → Leadership Model → UI。
- **替换平台绑定层**：macOS 菜单栏 / Cocoa / SwiftUI / macOS 工具链 → Windows 托盘 / 原生 UI / Windows 工具链。
- **保持本地优先、隐私优先**：不上传 usage、线程、路径、日志或账户数据。

### 1.3 非目标

- 不追求一套代码同时跑 macOS + Windows（除非选型天然支持）。
- 不直接在当前 Swift/Cocoa 仓库里硬塞 Windows 兼容代码。
- 不改变 AI 领导力评分模型 v1.3 的算法语义。

---

## 二、核心判断：架构可复用，平台绑定层必须重写

| 层级 | macOS 实现 | Windows 方案 | 可复用度 |
|---|---|---|---|
| **Domain 模型** | `LeadershipModel`、`TokenBreakdown`、`UsageTrend` 等纯 Swift struct | 直接翻译为同构数据类型 | **高** |
| **数据读取逻辑** | `ClaudeCodeRuntimeProvider`、`LeadershipDataReader` 的文件/JSONL/SQLite 解析 | 路径不同，解析逻辑几乎一致 | **高** |
| **Provider 抽象** | `RuntimeUsageProvider` 协议 | 用 interface / trait 复现 | **高** |
| **聚合与评估** | `AgentUsageAggregator`、`LeadershipAggregator` | 算法直接移植 | **高** |
| **系统托盘 / 菜单** | `NSStatusItem` + SwiftUI Popover | Windows 系统托盘 + 弹出窗口 | **低（重写）** |
| **主窗口 UI** | SwiftUI + Liquid Glass | 选型依赖 | **低（重写）** |
| **构建与打包** | `swiftc` + `codesign` + DMG | 新语言工具链 + MSI/MSIX/便携版 | **低（重写）** |
| **平台工具** | `sips`、`sqlite3`、`osascript` | 内置库或等价工具 | **中** |

**结论**：核心 pipeline 的 70% 可以通过"翻译 + 路径适配"复用；托盘、UI、打包、签名必须重写。

---

## 三、候选技术栈

### 3.1 方案 A：Rust + Tauri（推荐）

| 维度 | 评估 |
|---|---|
| **性能** | 高，Rust 原生 + Tauri 前端体积远小于 Electron。 |
| **系统托盘** | Tauri v2 原生支持 Windows 系统托盘与菜单。 |
| **UI** | Web 前端（React/Vue/Svelte），可高度还原 codexU 的视觉。 |
| **核心算法** | Rust 实现，可独立为 crate，方便单测。 |
| **SQLite/JSONL** | `rusqlite`、`serde_json`、`tokio::fs` 都很成熟。 |
| **打包** | Tauri 内置 MSI/NSIS/MSIX。 |
| **跨平台潜力** | 未来如果要回哺 macOS/Linux，成本最低。 |
| **缺点** | 需要重写 UI；Rust 学习曲线较陡；Tauri 与 Windows 深度集成（如 Acrylic/Mica）不如原生。 |

### 3.2 方案 B：C# + WinUI 3

| 维度 | 评估 |
|---|---|
| **性能** | 中上，.NET 9 AOT 后启动快。 |
| **系统托盘** | Windows 原生 NotifyIcon，最成熟。 |
| **UI** | WinUI 3 / WASDK，原生 Windows 外观，支持 Mica/Acrylic。 |
| **核心算法** | C# 直接翻译 Swift struct 与算法，开发效率高。 |
| **SQLite/JSONL** | `Microsoft.Data.Sqlite`、`System.Text.Json` 成熟。 |
| **打包** | MSIX / 单文件 EXE / MSI。 |
| **跨平台潜力** | 低，基本锁定 Windows。 |
| **缺点** | 未来无法复用；.NET 运行时依赖（可用 AOT 解决）。 |

### 3.3 方案 C：Go + Wails

| 维度 | 评估 |
|---|---|
| **性能** | 高，Go 编译快、二进制小。 |
| **系统托盘** | Wails v2 支持 systray，但社区成熟度低于 Tauri。 |
| **UI** | Web 前端。 |
| **核心算法** | Go 移植容易，但类型系统不如 Rust/C# 表达力强。 |
| **缺点** | Windows 深度集成能力弱于 Tauri/C#；社区生态较小。 |

### 3.4 方案 D：Electron

| 维度 | 评估 |
|---|---|
| **性能** | 低，内存占用大，启动慢。 |
| **系统托盘** | 成熟。 |
| **UI** | Web 前端。 |
| **缺点** | 与 codexU "小而快" 的产品气质不符；打包体积大。 |

### 3.5 推荐排序

1. **Rust + Tauri**：最佳长期架构，与 codexU "本地、快速、隐私" 气质一致，未来可扩展。
2. **C# + WinUI 3**：如果只求最快出 Windows 版、最好 Windows 原生体验。
3. **Go + Wails**：折中，但生态成熟度不如前两者。
4. **Electron**：不推荐。

---

## 四、Windows 数据路径调研清单（Phase 0 已完成）

在写第一行代码前，先确认以下路径和格式：

### 4.1 Codex on Windows

- [x] Codex CLI / Codex 桌面应用是否支持 Windows？
- [x] Windows 上 `~/.codex/` 对应 `%USERPROFILE%\.codex\` 还是 `%LOCALAPPDATA%\Codex\`？
- [x] `state_5.sqlite` 文件路径与表结构是否与 macOS 一致？
- [x] `sessions/**/*.jsonl` / `archived_sessions/*.jsonl` 路径与事件格式是否一致？
- [x] `automations/**/automation.toml` 是否存在？
- [x] Windows 上是否有 `codex app-server` 或等价的本地 API？

### 4.2 Claude Code on Windows

- [x] Claude Code 是否有 Windows 原生版本？
- [x] Windows 上 `~/.claude/projects/**/*.jsonl` 对应路径？
- [x] Windows 上 `~/.claude/tasks/**/*.json` 对应路径？
- [x] `~/.claude.json` 全局状态文件是否存在？
- [ ] Claude Code statusLine snapshot 在 Windows 上如何生成？

### 4.3 通用

- [x] Windows 上 JSONL 文件编码是否为 UTF-8（含 BOM 问题）？
- [x] Windows 上 SQLite 是否可用系统 `sqlite3.exe`，还是需要内嵌？
- [ ] Windows 路径分隔符、符号链接、文件锁对扫描是否有影响？（可在 phase-1 验证）

### 4.4 Phase 0 关键结论

- **数据根**：Codex 与 Claude Code 的实际数据根均为 `%USERPROFILE%\.<name>`，与 macOS 的 `~/` 模式一致。
- **state_5.sqlite**：存在且 schema 与 macOS 一致（含 `threads`、`rollout_path`、`thread_spawn_edges`）。
- **sessions JSONL**：活跃 sessions 与 archived sessions 均存在；顶层字段为 `payload`、`timestamp`、`type`，具体事件类型需解析 `payload`。
- **automations**：存在 3 个 automation（`opengu-daily-log`、`travel-map`、`check-cc-switch-issue-4885`），`automation.toml` 结构与 macOS 设计一致。
- **app-server**：`codex app-server --help` 可用，本地额度 API 可依赖。
- **Claude Code transcripts**：存在，字段结构与 macOS 预期一致；`tasks/*.json` 与 statusline snapshot 尚未生成，可延后。
- **编码**：JSONL 为 UTF-8 无 BOM，可直接用标准库读取。

完整探测结果见 [`roadmap/phase-0-research/findings.yaml`](./roadmap/phase-0-research/findings.yaml)。

---

## 五、迁移范围与任务拆分

### 5.1 第一阶段：核心 Domain + 数据读取原型

- 目标：在 Windows 上读取 Codex/Claude 数据，输出与 macOS `--dump-json` 等价的 JSON。
- 工作：
  - 翻译 `TokenBreakdown`、`DetailedUsage`、`UsageTrend`、`LocalUsage` 等模型。
  - 翻译 `ClaudeCodeRuntimeProvider` 的 JSONL 流式解析与缓存。
  - 翻译 `LeadershipDataReader` 的 SQLite 查询与 fingerprint 缓存。
  - 适配 Windows 路径。
- 可交付：命令行工具 + 单测。

### 5.2 第二阶段：聚合、评估与任务板

- 目标：复现 `MultiRuntimeUsageReader`、`AgentUsageAggregator`、`LeadershipAggregator`。
- 工作：
  - 实现 `RuntimeProvider` trait/interface。
  - 实现 Codex provider（先不依赖 app-server，只读本地）。
  - 实现 Claude Code provider。
  - 复现 AI 领导力评分。
- 可交付：核心库 + 单测。

### 5.3 第三阶段：Windows UI 与系统托盘

- 目标：系统托盘 + 弹出菜单 + 主窗口仪表盘。
- 工作：
  - 系统托盘图标与菜单。
  - 主窗口：额度环、趋势图、任务板、AI 领导力。
  - 设置窗口：语言、外观、状态栏配置。
- 可交付：可运行的 GUI 应用。

### 5.4 第四阶段：打包、签名与发布

- 目标：MSI/MSIX/便携版 + 自动更新。
- 工作：
  - 打包脚本。
  - 代码签名（可选）。
  - GitHub Release 集成。
- 可交付：安装包。

---

## 六、建议的协作方式

由于原仓库是 macOS Swift/Cocoa 项目，建议：**独立 fork / 新项目**，而不是直接提 PR 到原仓库。

可选方案：

1. **独立项目 `codexU-windows`**：
   - 由社区维护。
   - 与原项目共享架构设计和数据模型文档。
   - 发布到自己的 GitHub Release。

2. **官方子项目 / monorepo**：
   - 如果原作者愿意，可以设立 `shanggqm/codexU-windows`。
   - 原仓库 focus macOS，Windows 仓库独立迭代。

3. **直接 PR 到原仓库**：
   - 风险高，需要原作者明确同意。
   - 只有在原仓库里新增一个完全独立的 `windows/` 子目录时才可行。

**建议下一步**：先在本仓库提交一份 RFC issue，说明要做一个 Windows port，询问原作者倾向于哪种协作方式。

---

## 七、待决策问题

1. 选择 Rust + Tauri 还是 C# + WinUI 3？
2. 是否先只做 Codex，后补 Claude Code？
3. Windows 上是否需要支持 `codex app-server` 额度 API，还是先用本地数据？
4. 项目以 fork 还是官方子项目形式存在？
5. 是否复用 codexU 的品牌名和配色系统？

---

## 八、相关文档

- [`roadmap/phase-0-research/RESEARCH.md`](./roadmap/phase-0-research/RESEARCH.md) —— Windows 数据路径调研报告
- [`roadmap/phase-0-research/findings.yaml`](./roadmap/phase-0-research/findings.yaml) —— 结构化探测结果
- [`../architecture/schema.yaml`](../architecture/schema.yaml) —— macOS 版本架构真值
- [`../architecture/BLUEPRINT.md`](../../BLUEPRINT.md) —— macOS 版本完整蓝图
- [`./blueprint/schema.yaml`](./blueprint/schema.yaml) —— Windows 版本架构 schema（待创建）
- [`./blueprint/BLUEPRINT.md`](./blueprint/BLUEPRINT.md) —— Windows 版本架构蓝图（待创建）
