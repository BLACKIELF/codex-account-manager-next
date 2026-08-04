# 发现与决策

## 需求

- 用户要求先在本机分两阶段推进：先做真实应用截图 demo，再做正式实操。
- 截图由 agent 手动验收；未来也以真实截图加人工检查和调整为主，而非将视觉决策完全交给像素 diff。
- 运行不得占用既有 app、浏览器 profile 或端口。可只读使用真实本地 Codex 数据；截图产物不得提交或上传。

## 已验证现状

- `windows/apps/codexu-tauri/web/package.json` 只有 `dev`、`build` 与 `preview`，尚无 Playwright、Vitest、视觉脚本或截图配置。
- 当前前端在普通浏览器中不能直接运行，因为页面依赖 Tauri runtime；这支持把真实 Tauri app 而不是浏览器 mock 作为首批验收表面。
- 历史原生截图存在，但不是当前 HEAD 的可重复自动化视觉回归。
- 当前 `windows/AGENTS.md` 已明确要求 locator 级截图断言、隔离运行和本地图片产物。
- 阶段一已用实际 release Tauri 应用和真实本地 Codex 数据完成原生采集；没有使用 Computer Use、Playwright、fixture、浏览器 mock、baseline 或 pixel diff。
- Windows Graphics Capture 可按精确应用 HWND 正确获取 WebView2/GPU 内容；桌面抓屏、PrintWindow 和窗口 DC 均不适合作为本应用的正式路径。
- 960×760 对应 1445×1187 的原生物理帧，720×540 对应 1085×857；两个尺寸下均完成 Overview、Tasks、AI Leadership、Usage、Projects、Skills，共 12 张。
- 最终截图保存在 Git 忽略的 `.local-artifacts/windows-visual-captures/2026-07-30-full-surface-demo/screenshots/`。
- 两份阶段一报告已生成：`docs/windows-port/reports/WINDOWS_VISUAL_CAPTURE_DEMO.md` 与 `.html`。

## 技术决策

| 决策 | 理由 |
|------|------|
| 阶段一采用当前 checkout 的独立分支 PoC | 用户明确要求独立 branch、不使用 worktree；通过聚焦分支与临时目录控制范围。 |
| 真实原生应用和真实本地数据为默认输入 | 验收对象就是用户实际使用的 Windows app；读取保持只读。 |
| agent 手动截图验收为默认决策机制 | 机器负责生成可复核证据，视觉正常与否、是否调整由人工判断。 |
| 不引入 fixture、Playwright 或像素 golden 作为第一阶段前提 | 它们不服务当前 demo 的核心目标，可在将来稳定后按需加入。 |
| Tasks 文本属于 agent 使用记录 | 用户明确说明该内容是预期的产品信息；阶段一按正常内容验收，阶段二不承担相关产品改造。 |

## 已知限制

- 真实数据会变化，因此人工验收必须记录窗口尺寸、日期、应用版本、检查范围和结论，不能只写“看起来正常”。
- 单次人工截图只能证明当次构建；它不替代 build、合同测试或后续再采集。
- 720×540 的 Projects 长页面详情帧未同时显示选中 Tab；内容本身可读，阶段二需改善正式脚本的紧凑尺寸取景。

## 阶段二实现调查

- 当前正式仓库尚无 PowerShell 视觉采集入口；`windows/` 下只有 Tauri frontend hook，根 `scripts/` 以 macOS shell/Python 构建与验证脚本为主。
- 阶段一参考驱动已证明三项可复用行为：UI Automation 选择真实 Tab、滚动消息仅发送到当前 app 的 `Chrome_RenderWidgetHostHWND`、截图 helper 通过 `Windows.Graphics.Capture` 按主窗口精确 HWND 获取 WebView2/GPU 帧。
- 阶段一的 `GraphicsCaptureSnapshot.exe` 来自本机临时目录，仓库内没有其源码或可重复编译步骤；阶段二必须把 helper 源码纳入仓库，并把编译产物留在每次 `.local-artifacts/` 运行目录。
- 正式入口应从 `windows/` 运行已验证的 MSVC Tauri release 构建，目标 executable 为 `windows/target/release/codexu-tauri.exe`。
- `.gitignore` 已覆盖整个 `/.local-artifacts/`；正式入口仍需在运行前验证输出目录位于该边界且被 Git 忽略。
- 为避免接管用户实例，启动前应拒绝已存在的同一精确 executable；运行中记录 app 及其 WebView2 后代的 PID/创建时间/路径身份，清理时只处理匹配记录身份的精确任务进程。
- 紧凑取景不应再使用所有页面相同的固定滚轮次数；应以 UI Automation 的 Tab/Panel 可见性停止滚动，Projects 不增加额外滚动，以优先保留选中 Tab 和内容上下文。

## 阶段二正式运行视觉发现

- 第三次正式入口完成构建并生成 12 个 PNG；逐张人工检查不能以文件存在或 helper 的 `CAPTURE_OK` 代替图像内容检查。
- 960×760 Overview 帧内容完整：Header、指标卡、进度区、Tab 与首个内容区层级清楚，卡片和导航对齐正常，等待/估算口径可辨。
- 960×760 Tasks 在 `detail=original` 的首次工具预览中只显示标题栏，但像素采样显示其不透明/非白内容比例与 Overview 一致；改用 `detail=high` 复核后确认 PNG 内容完整，Tab、任务列与真实长文本均可读。该现象属于查看工具预览异常，不是空 compositor frame。
- 同组 960×760 AI Leadership 与 Usage 帧均有效：选中 Tab 和内容标题/卡片在同一帧；AI Leadership 的等级、周期、徽章与首屏详情层级可辨，Usage 的汇总卡与估算标签对齐、无可见水平溢出。
- 960×760 Projects 帧有效，且正式取景已实现选中 Projects Tab、列表标题与项目行同帧；数值列、相对条和辅助估算行对齐。
- 960×760 Skills 帧内容有效，但页面主体出现明显横向偏移/左侧裁切，只有后部 Tabs 完整可见；需要在选择 Tab 后对当前 renderer 显式横向归零。
- 720×540 Overview 帧有真实内容，但原生帧为 724×587，并出现底部水平滚动条；这与阶段一同尺寸的高 DPI 物理帧口径不一致，需核查 sizing 的 DPI awareness，而不能只信 `GetClientRect` 的 720×540 字符串。
- 720×540 Tasks 帧的选中 Tab 与 Tasks section 标题同帧且画面有效，但没有露出任务卡内容，无法用于长文本/列表验收；正式取景还需在保持 Tab 可见的前提下多推进内容。
- 720×540 AI Leadership 与 Usage 帧均有效，选中 Tab、section 标题/首个指标在同一帧；但有效内容高度偏少，AI Leadership 只露出标题开头，Usage 只露出首卡开头，仍不足以完整检查图表/核心卡片。
- 紧凑页共同表现为两行 Tab 占据较多高度；取景停止条件应要求 Tab 仍可见且 panel 至少露出一个可检查内容块，而非仅依据 panel `IsOffscreen = false`。
- 720×540 Projects 帧改善了阶段一“看不到选中 Tab”的问题：Projects Tab 与 section 标题/总数同帧；但未露出项目行，仍不足以验收列表对齐与长名称。
- 720×540 Skills 帧有效，选中 Tab 与完整无记录空态同帧，图标、标题和说明层级可读；这是当前紧凑组中内容取景最完整的页面。
- 第三次运行 12 张已逐张查看完毕并经 Tasks 二次复核：12 张均有真实内容；960×760 Skills 横向偏移，紧凑组多页内容露出不足且 Overview 出现水平滚动条。因此本运行集整体仍不通过，不能用于阶段二完成报告。
- DPI 探针确认当前正式入口的宿主 PowerShell 线程为 `DPI_AWARENESS_UNAWARE`。这解释了 720 组虽被虚拟化 `GetClientRect` 读作 720×540，但 WGC 物理帧只有 724×587；正式 sizing 必须把逻辑 client size 按 `GetDpiForWindow` 换算为物理 client 后再调用 `SetWindowPos`。

## DPI/取景修复后诊断集

- 修复后 960×760 记录为 physical client 1440×1140、WGC frame 1444×1187；720×540 记录为 physical client 1080×810、WGC frame 1084×857，均位于 144 DPI，恢复了阶段一口径。
- 新 960×760 Overview 仍保持完整首屏层级、卡片对齐、等待/估算标识和 Tab/内容关系。
- 新 960×760 Tasks 取景明显改善：选中 Tab 固定在同帧顶部，两个任务列、多个真实卡片、长文本换行、状态 pill 与更新时间均可直接检查，无水平裁切。
- 新 960×760 AI Leadership 同帧保留选中 Tab、周期/证据说明、等级轨道、四张指标卡与分项列表开头；层级、卡片对齐和长标签均无重叠。
- 新 960×760 Usage 同帧保留选中 Tab、四张汇总卡与图表开头；估算口径标签可辨，列对齐正常，无水平溢出。
- 新 960×760 Projects 同帧显示选中 Tab、列表标题、多条项目行、相对条和辅助估算行；长名称与右侧数值列保持对齐，未发生裁切。
- 新 960×760 Skills 已消除上一诊断集的横向偏移；选中 Tab、完整空态图标/标题/说明均位于同帧，左右边界与其他页面一致。
- 新 720×540 Overview 无水平滚动条或横向裁切，Header、状态行、等级卡与 quota 卡开头层级清楚；纵向滚动条反映紧凑视口的正常长页。
- 新 720×540 Tasks 将选中 Tab、section 标题、列表标题和多张真实任务卡纳入同帧；长文本能在卡片内换行，状态 pill 和更新时间不重叠。

## 最终默认运行人工验收

- 最终默认运行重新执行 release 构建后生成 12 张原始 PNG；所有原图尺寸均与 manifest/WGC 记录一致。
- 查看工具再次把 960×760 Tasks 原图错误折叠为标题栏预览；原图像素尺寸、文件体积以及同目录等比例审阅副本均证明完整内容存在。审阅副本仅用于 agent 查看并留在 Git 忽略的本地运行目录，不替代原始截图。
- 最终 960×760 Overview 的 Header、状态、等级/配额/汇总卡、进度区和 Tab/内容开头均完整；卡片网格、语义色和等待/估算口径清楚。
- 最终 960×760 Tasks 的选中 Tab、两列列表、任务卡、长文本换行、状态 pill 与时间标签同帧可辨，无横向裁切或卡片重叠。
- 同次 960×760 AI Leadership 与 Usage 均保住选中 Tab，但即时停止策略过于保守：AI Leadership 仅露出标题/等级图，Usage 仅露出首排汇总卡，取景深度较上一诊断集退化。
- 根因不是窗口高度不足，而是先前 150ms 轮询会在 WebView2 平滑滚动尚未落定时继续排队滚轮；简单改成“首次同帧立即停止”消除了过滚，却牺牲内容深度。正式策略应在每个滚轮后等待滚动落定，再按首选 Tab 高度或真实页尾决定是否继续。
- 650ms 落定策略的诊断复跑中，960×760 AI Leadership 恢复选中 Tab、标题/周期、等级环/轨道及四张指标卡同帧；960×760 Usage 恢复选中 Tab、四张汇总卡和图表标题同帧，未再次过滚。
- 同一诊断集的 960×760 Projects 显示选中 Tab、列表标题和多条完整项目行；960×760 Skills 显示选中 Tab 与完整空态，横向位置稳定。Projects 页尾受限时允许 Tab 位于首选线以下，但列表内容仍足以检查对齐、长名称和相对条。
- 650ms 策略下 720×540 Overview 保持 Header、状态、等级卡与 quota 卡开头完整，无水平滚动条；720×540 Tasks 同帧显示选中 Tab、列表标题和多张任务卡，长文本正常换行。
- 720×540 AI Leadership 同帧保留选中 Tab、标题/周期、等级标签和等级环主体；720×540 Usage 同帧保留选中 Tab、两张完整汇总卡和下排两卡主体，列对齐且估算标签可辨。
- 重点页 720×540 Projects 达到目标：选中 Tab、列表标题、总数、多条完整项目行、右侧数值列和相对条同帧，无横向裁切。
- 720×540 Skills 在真实空态下保留选中 Tab、完整图标/标题/说明和上方口径卡，同帧层级清楚；页面左右边界稳定。
- 650ms 诊断集的 12 张已逐张查看，取景、DPI 与横向归零均通过；下一步必须再用默认命令重新构建并生成最终证据集，不能把 `-SkipBuild` 诊断集作为最终交付。
- 最终默认复跑的 960×760 Overview 与 Tasks 已逐张通过：前者覆盖完整仪表盘层级和首个列表区域，后者覆盖选中 Tab、两列列表、多张真实卡片与长文本换行；没有布局跳位、横向裁切或重叠。
- 最终 960×760 AI Leadership 与 Usage 已逐张通过：AI Leadership 的等级环/轨道与指标卡对齐，Usage 的四张汇总卡和图表标题完整；两帧均保留选中 Tab 和对应内容。
- 最终 960×760 Projects 与 Skills 已逐张通过：Projects 的列表行、右侧列、相对条和辅助估算行对齐；Skills 的选中 Tab 与完整真实空态同帧，横向归零有效。
- 最终 720×540 Overview 与 Tasks 已逐张通过：Overview 无水平滚动条且紧凑层级清楚；Tasks 的选中 Tab、列表标题、多张卡片和长文本同帧，紧凑滚动位置正确。
- 最终 720×540 AI Leadership 与 Usage 已逐张通过：前者保留选中 Tab、等级标题/标签和等级环主体，后者保留选中 Tab、两张完整卡及下排卡主体；紧凑列宽和长标签未发生碰撞。
- 最终 720×540 Projects 与 Skills 已逐张通过：Projects 的选中 Tab、标题、总数和多条完整项目行同帧，重点取景目标达成；Skills 的选中 Tab 与完整空态同帧且无横向偏移。
- 最终默认运行 12/12 张均已由 agent 逐张查看。此次真实数据快照覆盖正常内容、等待状态和 Skills 空态；未出现产品错误态，因此不能据此声称错误态视觉也已覆盖。
- 最终 manifest、原始 PNG 尺寸、任务进程身份、精确 release app、报告一致性和 Git ignore 边界均经独立只读复核；记录进程/精确 app 存活数均为 0。
- 阶段二通过范围仅是当前 checkout、当前 Windows/DPI 和当前真实只读快照；不构成像素 baseline，也不覆盖主题矩阵、dialog、系统菜单或未出现的终态错误。

## 视觉/浏览器发现

- 本轮启动并清理了任务自有的真实 Tauri 应用实例；未使用浏览器测试或 Computer Use。
- 用户已授权真实本地数据作为默认的只读本机验收输入，并确认 fixture 不重要。
- Overview 与五个 Tab 在两个窗口尺寸下均可读；卡片层级、对齐、长文本换行、空态、图表、滚动和数据口径满足本轮 demo 目标。
- Tasks 中出现的活动描述是预期的 agent 用量/使用记录，阶段一验收通过。

## 全屏六表面复核（2026-08-01）

- 当前主显示器为 2560×1440，最大化工作区为 2560×1368；Tauri 最大化窗口 client 为 2560×1334，DPI 为 144。
- 本地全屏驱动一次启动真实 release app，依次选择五个真实 Tab，并按精确主 HWND 生成 Overview、Tasks、AI Leadership、Usage、Projects、Skills 六张 2560×1368 原始 PNG 与 1200px 等比例审阅副本。
- 用户已指出全屏 Tasks 肉眼可见有问题；首张 Overview 中可初步观察到多列卡片在居中限宽容器内被压窄，长文本形成过密换行。最终根因与修复范围需在专门 Tasks session 中结合源码和 RED 测试确认。
- 全屏运行结束后精确 release app 为 0；一个 WebView2 PID 在清理复核时身份已变化，脚本未触碰该 PID，且没有仍匹配记录身份的任务进程。
- 全屏 Overview 与 Tasks 两张画面完全相同，因为 Tasks 是默认选中 Tab；这不是缺图，而是 Overview 定义为页面顶部加默认 Tasks 内容。
- 两张图共同确认 Tasks 问题：Dashboard 主内容被固定在约三分之二屏宽的居中容器内，Tasks 又强制分成四列，导致活动卡片宽度过窄、长文本逐词密集换行；右侧大量屏幕空间未利用。问题同时涉及 Dashboard 全屏容器策略与 TaskBoard 的大屏列宽/列数约束，需在同一 Tasks 布局 session 中追踪 CSS 根因，避免只给文本打补丁。
- 全屏 AI Leadership 的选中 Tab、标题、等级环/轨道和首排指标卡层级正常，没有发现独立的重叠或裁切问题；其主要限制仍是 Dashboard 全局居中限宽，而非 Leadership 模块自身布局。
- 全屏 Usage 的四张汇总卡与两张图表在当前限宽内对齐正常，轴线和标签可辨；同样存在整体只使用屏幕中部区域的问题，但未发现需要单独 Usage session 的模块级缺陷。
- 全屏 Projects 的 Projects/Tools 双栏、数值列和相对条对齐正常，没有长名称溢出；当前截图未显示需要独立 Projects session 的问题。
- 全屏 Skills 的选中 Tab 与完整空态同帧，图标、标题和说明居中稳定；未发现需要独立 Skills session 的问题。
- 六表面共同问题是 Dashboard 大屏容器未利用工作区宽度；Tasks 因四列和长文本组合最严重。当前问题归类为一个关联的“Dashboard 全屏容器 + Tasks 大屏网格”布局域，而不是为 AI Leadership、Usage、Projects、Skills 分别创建无必要 session。

## Tasks 首轮修复后全屏复核（2026-08-01）

- 已重建 release 并按精确 HWND 生成首轮修复后全屏六图；采集 manifest 为 complete，记录进程无 identity mismatch 与 remaining。
- Overview 与 Tasks 首对截图证明：状态 footer 已与标题分离，四列顶部对齐改善；但 `line-clamp-2` 产生了肉眼可见的省略号。
- 省略号与用户明确的“Tasks agent 活动文本不得隐藏、摘要化或 redaction”边界冲突，因此首轮视觉结果不通过，不继续把其他四张当作最终证据。
- 修正设计：保留独立状态 footer 与 `min-h-10` 最小两行区，移除标题 `line-clamp-2`，标题完整换行显示并允许卡片随内容增高。

## Tasks 最终修复后全屏复核（2026-08-01）

- Overview/Tasks 首对：四个状态列顶部对齐，标题不再被 CSS clamp/truncate/ellipsis 截断，长标题在独占宽度内完整换行并推高卡片；状态标签位于底部分隔区，不再与标题争宽。
- 画面中仍可见的字面省略号来自本地任务标题本身；当前组件源码与契约已明确禁止标题 `line-clamp`、`truncate` 和 `text-ellipsis`，本轮未修改数据读取或内容。
- Overview 与 Tasks 依然为同一画面，原因是 Tasks 是 Dashboard 的默认活动 Tab；两个文件均为本次实际独立采集。
- AI Leadership/Usage 第二对：选中 Tab 与对应内容同帧清晰可辨；Leadership 标题、徽章、轨道、当前分数与下方指标卡对齐，Usage 四张摘要卡与两个图表区对齐，未见 Tasks 修复引入的回归。
- 两个表面的长文本、数值层级、图表轴/轨道和列宽均正常；当前真实数据状态可读，未见空状态或错误态被伪造为零值。
- Projects/Skills 第三对：Projects 的项目/工具两列共享顶线，数值右对齐、名称左对齐、相对条形稳定，全屏顶部取景同时保留选中 Tab 与多条列表；Skills 的真实空状态居中、层级清晰，未伪造记录。
- 六张最终全屏图均在同一 release 构建和同一次本地只读数据快照下采集，无断裂布局、重叠、水平滚动、图表裁切或 Tasks 修复导致的其他模块回归。
