# 任务计划：Windows 本机视觉验收两阶段落地

## 目标

先以真实 Windows 应用和真实本地数据完成一次可审阅的截图 demo，再把启动、采集、人工视觉验收和清理流程固化到当前 checkout 的 Windows Dashboard 日常开发中；未经用户明确要求不提交、不合并、不 push。

## 当前阶段

阶段 1：真实应用截图 demo，已完成。阶段 2：正式接入 Windows Dashboard，已完成。阶段 3：全屏六表面复核与模块修复，已完成。

## 各阶段

### 阶段 1：真实应用截图 demo

- [x] 从当前直接父基线在现有 checkout 创建并切换到独立 `codex/windows-visual-capture-demo` 分支；不创建或切换 worktree。（基线：`windows-port/ui-dev` 的 `c4d58f3`）
- [x] 构建并只启动本任务的当前 Windows Tauri 应用，使用真实本地 Codex 数据；未增加 fixture、Playwright 或截图 diff。
- [x] 以 960×760 和 720×540 采集 Dashboard overview、Tasks、AI Leadership、Usage、Projects、Skills；共 12 张本机截图。
- [x] 由 agent 手动检查布局、信息层级、卡片对齐、长文本、空/错误状态、滚动和真实数据口径。
- [x] 记录本任务启动的 app 与 PID，并在采集完成后确认 app 及其 WebView2 子进程退出。
- [x] 确认真实数据只读使用，未修改数据读取、评分、缓存、IPC 或产品 UI。
- [x] 将截图保存到 Git 忽略的 `.local-artifacts/windows-visual-captures/`，未提交、上传或嵌入报告。
- **验收门槛：** 当前原生应用在两个窗口尺寸均获得可读截图；人工检查结论逐项记录；所有本任务启动的进程已退出。
- **状态：** complete

### 阶段 2：正式接入 Windows Dashboard

- [x] 将阶段一验证成功的 Windows Graphics Capture 流程整理为仓库内正式本机采集命令：构建、启动实际 Tauri 应用、设定窗口尺寸、采集截图、清理本任务实例；不使用 Computer Use，不引入 fixture 或像素 golden gate。
- [x] 将截图路径、临时产物和进程清理写入忽略规则与运行说明；截图、日志和真实数据均不提交或上传。
- [x] 默认覆盖 960×760 与 720×540 下的 Dashboard overview、Tasks、AI Leadership、Usage、Projects、Skills；改善紧凑尺寸长页面的取景，使选中 Tab 与内容上下文尽量同帧可辨。
- [x] 为每个受影响区块建立人工验收清单：可见性、层级、对齐、长文本、空/错误状态、滚动和数据口径；保留现有 build 与源码合同测试作为基础自动检查。
- [x] 把真实 Tauri/WebView2、窗口尺寸/DPI 和打包资源作为唯一的视觉验收表面；未引入浏览器验收路径。
- [x] 在当前 checkout 重新运行受影响验证并记录明确的未提交范围；未提交、未合并、未 push，且本地图片、数据、日志和构建产物仍处于忽略边界。
- **验收门槛：** 所有受影响区块都有当前原生应用的本机截图和人工验收记录；真实数据读取只读、任务 runtime 隔离；release build、合同测试、源码测试和本机视觉检查均通过；任务进程全部退出。
- **状态：** complete

### 阶段 3：全屏六表面复核与模块修复

- [x] 最大化真实 release Tauri 窗口，并按精确 HWND 采集 Overview、Tasks、AI Leadership、Usage、Projects、Skills 六张 2560×1368 原生截图。
- [x] 逐张人工检查六个全屏表面，并把问题按独立模块归类。
- [x] 对确认的问题模块分别建立独立 session，先完成根因分析与 RED 合同测试，再修改产品 UI。
- [x] 集成各模块最小修复，保持真实数据只读，不修改 reader、评分、缓存或 IPC。
- [x] 重新执行 Web/Rust/release 构建与全屏六表面采集，逐张验收修复结果。
- [x] 更新配对报告与未提交文件清单；未经明确要求不 commit、不 merge、不 push。
- **验收门槛：** 六张全屏图逐张通过；Tasks 长文本和多列布局在全屏下可读；其他模块不得出现回归；精确任务进程全部退出。
- **状态：** complete

## 已做决策

| 决策 | 理由 |
|------|------|
| 采用两阶段而非直接全面接入 | 先用真实 app 证明截图与人工检查流程有效，再把它收敛为日常验收。 |
| 当前不以 Playwright、fixture 或 pixel diff 为前提 | 用户强调真实数据和人工调整；这些自动化能力可以在稳定后再评估。 |
| 原生 Tauri 为视觉验收表面 | 它同时覆盖真实数据、WebView2、窗口装饰、DPI 和打包资源。 |
| 截图产物仅本地保留 | 遵守 Windows 目录规则，避免提交或上传本地数据与截图。 |
| 阶段一使用独立分支但不使用 worktree | 用户明确要求在当前 checkout 内完成，避免额外 checkout 带来的上下文分散。 |
| 使用真实本地数据作为默认验收输入 | 用户明确授权；读取必须只读，产物仅本地保留。 |
| Tasks 中的文本按 agent 使用/活动记录验收 | 用户明确说明这是产品要展示的 agent 用量信息，按预期产品内容验收。 |

## 关键问题

1. 阶段一覆盖范围已确定并完成：Dashboard overview 加五个 Tab，在两个尺寸下共 12 张。
2. 阶段二只固化原生采集与人工验收流程；不在该阶段引入浏览器 mock、fixture、baseline 或 pixel diff。

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| 当前项目没有统一截图采集命令 | 1 | 阶段一先验证真实 app 的人工采集；阶段二再固化最小命令。 |
| 早期桌面抓屏受到开始菜单遮挡 | 1 | 改用按精确 HWND 采集 WebView2/GPU 表面的 Windows Graphics Capture。 |
| PrintWindow/窗口 DC 不能获得有效 WebView2 内容 | 2 | 放弃该路径，使用 Windows Graphics Capture。 |
| 720×540 的部分长页面滚动后未在同一帧保留 Tab 上下文 | 1 | 使用 DPI-aware 客户区换算、显式横向归零，并在每次滚轮后等待 WebView2 平滑滚动落定；最终紧凑 Projects 同帧保留 Tab 与多条列表行。 |
| helper 误选 Windows SDK Facade metadata | 1 | 只选择版本化 `UnionMetadata/<SDK>/Windows.winmd`，并加入预检合同。 |
| 正式入口首次遗漏加载 native driver | 1 | 在预检和运行路径共同加载 driver，并以合同验证 DPI scaling probe。 |
| 查看工具把完整大图折叠为标题栏预览 | 2 | 核对原 PNG 尺寸/像素并在同一忽略目录生成等比例审阅副本；正式证据仍为原始 PNG。 |
| 平滑滚动未落定导致过滚或取景过浅 | 2 | 增加滚动落定合同与页尾 fallback，诊断通过后再执行默认 release 构建入口。 |
| 六图本地脚本被短命令超时中断 | 1 | 任务 app 随脚本 finally 路径退出；改用完成后读取 manifest 的方式确认六图已全部写入，不重复启动。 |
| 清理时一个已退出 WebView2 PID 身份发生变化 | 1 | 按安全边界不触碰身份不匹配 PID；后续复核确认没有仍匹配本次记录身份的进程。 |
| 首次查找任务看板合同时使用了不存在的文件名 | 1 | 用 `rg --files` 确认实际文件为 `task-board-contract.test.mjs`，改用真实路径。 |
| Windows `rg` 命令将带通配符的路径作为字面文件名 | 1 | 显式指定 `tailwind.config.ts`，不向 `rg` 传递 PowerShell 未展开的路径通配符。 |
| RED 契约一次将 TypeScript 非空断言误写入 `.mjs` | 1 | 修正为标准 JavaScript，然后重新观察由缺失布局契约导致的正常 RED。 |
| 首轮 Tasks 修复使用两行 clamp，原生图出现省略号 | 1 | 否决首轮视觉证据；契约改为禁止标题 clamp/truncate/ellipsis，标题保留最小高度但允许完整换行增长。 |
| 用 `git diff --no-index --check` 批量检查未跟踪文件时将“文件存在差异”的 exit 1 误当作空白错误 | 1 | 保留正式 `git diff --check`；对未跟踪文件另行解析 `--check` 的实际诊断行，只将真实空白诊断或 exit > 1 视为失败。 |

### 阶段三已确认设计与实施计划（2026-08-01）

**设计结论：** 采用 Tasks-only 修复。保留 Dashboard 居中 `max-w-6xl` 与四个状态列；任务标题改为独占宽度且至少两行高的区域，长标题完整换行并允许卡片增长，状态标签移到底部 metadata footer，detail 与事实时间保持原有语义。不删减、摘要、脱敏或改写 agent 活动文本，不修改 reader、评分、缓存或 IPC。

**不选方案：** 本轮不扩大全局容器到 1280 CSS px，因为会扩大六个模块的回归面；不把四列改为 2×2，因为会偏离 macOS 固定四状态列参考。

#### Task 1：Tasks 卡片长文本布局

- [x] 在 `windows/apps/codexu-tauri/web/tests/task-board-contract.test.mjs` 增加源码契约：标题区必须有 `min-w-0`、`min-h-10` 和 `break-words`，且禁止 `line-clamp`、`truncate` 或 `text-ellipsis`；footer 必须唯一渲染 `stateLabel(item)`。
- [x] 单独运行该契约并观察预期 RED，确认失败原因是新布局与防隐藏契约不存在。
- [x] 仅修改 `TaskBoardPanel.tsx`：标题独占宽度、保留最小两行高度并完整换行增长；detail/time 保留；状态 footer 与标题分离；完整标题保留为可访问文本与 `title` 提示。
- [x] 重跑定向契约并确认 GREEN。

#### Task 2：回归验证与全屏六图

- [x] 运行 web 全部测试和构建、Windows Rust workspace 测试、Tauri release 构建、PowerShell 语法/工作流契约与 `git diff --check`。
- [x] 通过本机 Windows Graphics Capture 正式方法重新生成 Overview、Tasks、AI Leadership、Usage、Projects、Skills 六张全屏截图。
- [x] Agent 逐张人工检查：Tasks 标题与状态可读，四列顶部对齐；其他五个模块无布局、图表、列表或空状态回归。
- [x] 确认任务 app 与 WebView2 子进程全部退出，更新配对报告和 `.planning`，保持未 commit、未 merge、未 push。

#### 计划自审

- 规范覆盖：长文本、状态位置、固定四列、数据不变、六模块回归、精确进程清理均有对应验证。
- 占位符扫描：无 TBD/TODO/“以后实现”。
- 文件边界：生产代码只修改 `TaskBoardPanel.tsx`，测试只修改现有 task-board contract；验收记录只更新既有 `.planning` 与报告对。
