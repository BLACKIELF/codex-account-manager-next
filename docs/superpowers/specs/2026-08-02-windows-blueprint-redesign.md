# codexU Windows Blueprint 重做设计

## 状态与范围

- 状态：视觉组织方案已由用户确认，等待书面规格复核。
- 范围：只使用当前 `windows-port/ui-dev` 检出中的 Windows 实现、Windows 文档、Windows 测试与构建脚本作为事实来源。
- 目标：重做 `docs/windows-port/blueprint/`，让主图同时解释 Windows 桌面运行链、每个架构块对应的自动化验证，以及原生自动截图 Demo 的真实位置。
- 非目标：不从 macOS `Sources/` 推导 Windows 架构；不展示未来规划模块；不把文件夹、类名或测试目录提升为同权重架构层；不把测试画成第二条业务泳道。

## 设计结论

采用“中心运行图 + 按对象挂接的验证卫星”。

中心是一个明确标注为 `codexU Windows Desktop Runtime` 的系统边界，内部放五个宏观运行块。测试、Probe、构建和截图证据位于系统边界外，并连接到各自真正验证或消费的对象。测试工具自身也允许成为被测对象，例如截图 Workflow Preflight 连接截图 Demo，而不是越级连接 UI。

## 中心运行图

中心图是混合拓扑，不是五步机械流水线。

| 块 | 责任 | 主要输入 | 主要输出 | 当前证据 |
| --- | --- | --- | --- | --- |
| 1. 本地证据与官方额度 | 定义 Windows 只读输入边界 | `state_5.sqlite`、sessions、archived sessions、automations、Codex app-server quota | 本地原始观察与官方额度窗口 | `windows/crates/codexu-core/src/readers/`、`codex_app_server.rs` |
| 2. 安全读取与隐私缩减 | 读取本地证据，并在 reader 边界缩减敏感内容 | 本地原始观察 | usage/task/skill 等安全观察 | `CodexStateReader`、`CodexTranscriptReader`、`CodexTaskBoardReader` |
| 3. 用量、任务与 Leadership 聚合 | 汇总本地观察，构建任务与 Leadership 视图，并合并/保留官方额度 | 安全观察、官方额度 | 完整 Dashboard 数据 | `make_local_usage`、`build_leadership_snapshot`、quota apply/retain |
| 4. Dashboard Snapshot 与 AppState/Tauri IPC | 固定前后端契约，管理缓存、single-flight、source generation 与刷新 | 聚合数据 | `CodexDashboardSnapshot`、Tauri commands/events | `codexu-models`、`app_state.rs`、Tauri command wiring |
| 5. Windows Desktop UI | 呈现 Overview、Tasks、AI Leadership、Usage、Projects、Skills 与 Settings | Dashboard Snapshot、设置和刷新事件 | 真实 Tauri/WebView2 桌面界面 | `windows/apps/codexu-tauri/web/src/`、`src-tauri/` |

主要运行关系：

1. 本地证据进入安全 readers，再进入聚合、Snapshot/AppState，最终进入 UI。
2. 官方额度是只读旁路，从输入边界直接进入聚合/Snapshot，不强行穿过 transcript/task readers。
3. UI 只消费已缩减的 Snapshot 契约，不显示 raw prompts、回复、tool arguments、raw logs 或敏感路径。

## 外围验证与交付卫星

外围节点不组成一条独立泳道，而是靠近并连接对应对象。

| 卫星节点 | 连接对象 | 关系 | 证据 |
| --- | --- | --- | --- |
| Quota protocol / continuity tests | 块 1、块 3 | 验证 app-server 解析、官方额度应用和旧值保留 | `codex_app_server_quota.rs`、`codex_dashboard_quota.rs` |
| Reader and aggregation Rust tests | 块 2、块 3 | 验证 SQLite/transcript/task/skills 缩减与 Leadership 聚合 | reader 模块单元测试、`task_board.rs` |
| AppState tests | 块 4 | 验证缓存、single-flight、generation 与重试行为 | `windows/apps/codexu-tauri/src-tauri/src/app_state.rs` |
| Web contract tests | 块 5 | 验证 React 组件层级、quota、Task Board、Skills 与 Leadership 布局契约 | `windows/apps/codexu-tauri/web/tests/*.test.mjs` |
| Native Screenshot Demo | 块 5 | 启动并捕获当前 checkout 的真实 Tauri release 窗口 | `windows/scripts/Capture-NativeVisuals.ps1`、`GraphicsCaptureSnapshot.cs` |
| Screenshot Workflow Preflight | Native Screenshot Demo | 验证截图引擎、exact HWND、六个 surface 与本地产物边界 | `windows/scripts/tests/Test-NativeVisualCaptureWorkflow.ps1` |
| Local visual evidence | Native Screenshot Demo | 接收 manifest、日志和两种尺寸下的 12 张截图 | `.local-artifacts/windows-visual-captures/`，仅本地、Git ignored |
| `codexu-probe` | 块 2、块 3 | 作为非 UI 的只读诊断消费者 | `windows/apps/codexu-probe/` |
| Build and package | 块 4、块 5、Native Screenshot Demo | 生成/提供精确 release executable，并负责 MSI/NSIS 交付 | Tauri config、Windows build scripts |

截图链必须画成：

`Screenshot Workflow Preflight --verifies--> Native Screenshot Demo --captures exact HWND--> Windows Desktop UI`

同时由 Screenshot Demo 指向 `local manifest + 12 screenshots`。这明确区分“测试 UI”和“测试截图工具”。

## 视觉与连线规则

- 中心运行边界使用最强视觉层级；五个运行块采用稳定的左到右阅读顺序。
- 外围卫星使用较小卡片，按被测对象分布在上方、下方或右侧，不形成第二条平行通道。
- 实线表示运行时数据/契约流；虚线表示 `verifies`；细实线表示 `builds`、`consumes`、`captures` 或 `produces`。
- 每条外围关系必须有具体动词，禁止只写 `uses`。
- 原生截图 Demo、Web contract tests 和 UI 形成三个相邻但不合并的节点：前两者验证 UI 的不同层面。
- 可以使用一个很轻的“Engineering verification and delivery”外围提示，但它不能包进 Runtime 边界，也不能造成所有测试覆盖所有模块的错觉。
- 主图保持约 5 个一级运行块和不超过 9 个外围卫星；实现文件只进入卡片说明或 `BLUEPRINT.md` 证据表。

## Blueprint 产物

沿用现有 `docs/windows-port/blueprint/` 位置并整体重建：

- `schema.yaml`：唯一架构事实源，包含稳定节点、边、groups、composition 与必要的 layout 提示。
- `diagram.mmd`：GitHub/Obsidian 可读的简化 fallback。
- `diagram.svg`、`diagram.html`、`diagram.render.png`：从 schema 确定性生成的维护版本。
- `diagram.generated.png`：从同一 schema 与 composition 生成的视觉候选。
- `diagram.png`：经过语义和视觉复核后选中的人类阅读版本。
- `BLUEPRINT.md`：架构定位、五块职责、数据契约、测试映射、隐私边界和当前验证状态。
- `render.py`：必要时作为项目本地确定性 renderer wrapper。

旧 Blueprint 中与当前 Windows 事实不一致的 Claude 主路径、多 runtime registry、旧 Leadership model、WinUI/Tauri 模糊边界和未落地更新器，不进入新 schema。

## 验收标准

1. schema 验证无错误，Mermaid 是 schema 的语义子集。
2. 图中能一眼识别五块 Windows 运行图，以及测试到具体对象的附着关系。
3. Native Screenshot Demo 直接连接 UI；其 Preflight 只连接 Screenshot Demo。
4. 官方额度旁路、本地读取主路径和 Probe 旁路没有被误画成单一串行链。
5. 确定性 SVG 通过 geometry 检查：无裁切、重叠、错误穿线和画布溢出。
6. `diagram.render.png` 与 `diagram.generated.png` 分别保留，选择 `diagram.png` 前完成语义忠实度与视觉质量对比。
7. `BLUEPRINT.md` 与图中的节点、边、测试映射一致，并明确本地截图证据不可提交或公开。
8. 文档改动至少通过 `git diff --check`；不得宣称未执行的 native、build 或测试结果。

## 明确排除

- 不在 Blueprint 中引用 macOS 实现来填补 Windows 空白。
- 不把浏览器测试描述成 WebView2、DPI、窗口装饰、原生对话框或真实 IPC 的证明。
- 不把一次成功截图描述成完整 UI 质量通过或视觉回归基线。
- 不把 `.local-artifacts` 中的真实截图、日志、路径或本地数据写入 Blueprint/报告或提交。
- 不新增产品代码、运行时依赖或业务架构层级；本次只重做 Windows 架构文档与其生成资产。
