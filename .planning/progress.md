# 进度日志

## 会话：2026-07-29

### 阶段 1：两阶段设计

- **状态：** complete
- 执行的操作：
  - 核验 Windows 自动视觉验收规则与当前前端脚本。
  - 确认没有现成的 Playwright、视觉测试脚本或基准图。
  - 将本机 PoC 与正式接入拆为两个独立验收阶段。
  - 根据用户澄清，将阶段一隔离方式调整为当前 checkout 的独立分支，不创建独立 worktree。
  - 根据用户确认，移除 fixture、Playwright 和像素 diff 作为前置；改为真实原生应用截图加 agent 手动验收。
  - 从 `windows-port/ui-dev` 的 `c4d58f3` 创建并切换至 `codex/windows-visual-capture-demo`；未创建 worktree。
- 创建/修改的文件：
  - `.planning/task_plan.md`
  - `.planning/findings.md`
  - `.planning/progress.md`

## 测试结果

| 测试 | 输入 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| 计划阶段 | 当前 Windows web 配置 | 不改生产代码或测试依赖 | 仅创建规划文件 | 通过 |

## 错误日志

| 时间戳 | 错误 | 尝试次数 | 解决方案 |
|--------|------|---------|---------|
| 2026-07-29 | 当前项目不存在视觉测试脚本 | 1 | 作为阶段一 PoC 的明确验证对象。 |

## 五问重启检查

| 问题 | 答案 |
|------|------|
| 我在哪里？ | 阶段一：两阶段设计与本机 PoC。 |
| 我要去哪里？ | 先通过 PoC，再正式接入 Dashboard。 |
| 目标是什么？ | 建立不干扰本机环境的可重复 Windows 视觉验收。 |
| 我学到了什么？ | 见 `findings.md`。 |
| 我做了什么？ | 见本文件阶段记录。 |

## 会话：2026-07-30

### 阶段 1：真实 Windows 应用截图 demo

- **状态：** complete
- 执行的操作：
  - 记录当前分支 `codex/windows-visual-capture-demo` 与 SHA `c4d58f347f41d6a93a177dbd2291fc8405ac342f`。
  - 完成前端构建、Rust workspace 测试与实际 release Tauri 构建验证。
  - 使用 Windows Graphics Capture 按精确 HWND 采集真实 WebView2/GPU 画面；未使用 Computer Use。
  - 在 960×760 与 720×540 下采集 Dashboard overview、Tasks、AI Leadership、Usage、Projects、Skills，共 12 张。
  - 由 agent 逐张检查布局、层级、对齐、长文本、空/错误状态、滚动和真实数据口径。
  - 将最终截图保存到 Git 忽略的 `.local-artifacts/windows-visual-captures/2026-07-30-full-surface-demo/screenshots/`。
  - 确认本任务 app 与 WebView2 子进程退出。
  - 生成并同步更新 Markdown/HTML 配对报告。
  - 根据用户澄清，将 Tasks 文本认定为预期的 agent 使用记录，并按正常产品内容验收。
- 创建/修改的任务文件：
  - `.gitignore`
  - `.planning/task_plan.md`
  - `.planning/findings.md`
  - `.planning/progress.md`
  - `docs/windows-port/reports/WINDOWS_VISUAL_CAPTURE_DEMO.md`
  - `docs/windows-port/reports/WINDOWS_VISUAL_CAPTURE_DEMO.html`

## 阶段一验证结果

| 验证 | 实际结果 | 状态 |
|------|---------|------|
| 前端 production build | 通过；保留既有 chunk-size warning | 通过 |
| Rust workspace tests | 49 tests passed，1 个需认证 Codex CLI 的 quota case ignored | 通过 |
| Tauri release build | 实际 release executable 构建成功并用于截图 | 通过 |
| 原生截图 | 6 个界面 × 2 个尺寸，共 12 张 | 通过 |
| 人工视觉验收 | 所有目标界面可读；紧凑 Projects 取景留待阶段二改善 | 通过 |
| 进程清理 | 任务 app 与 WebView2 子进程为 0 | 通过 |

## 阶段一错误记录

| 时间戳 | 错误 | 尝试次数 | 解决方案 |
|--------|------|---------|---------|
| 2026-07-30 | 桌面抓屏受到开始菜单遮挡 | 1 | 改用 Windows Graphics Capture。 |
| 2026-07-30 | PrintWindow/窗口 DC 无法获得有效 WebView2 内容 | 2 | 使用按精确 HWND 的 Graphics Capture helper。 |
| 2026-07-30 | 首次迁移截图时选中了早期无效临时目录 | 1 | 人工预览发现遮挡后删除错误副本，按最终 Graphics Capture 哈希重新复制。 |

## 阶段二启动状态

- **状态：** in_progress
- 启动核对：
  - 当前 checkout 分支为 `codex/windows-visual-capture-demo`，起始 SHA 为 `934d9e395efabab2694ba5cce97c83db0bae87c9`。
  - 保留阶段一已有未提交内容：`.gitignore`、`.planning/` 与 `WINDOWS_VISUAL_CAPTURE_DEMO` 配对报告；未创建或切换 worktree。
  - 启动前 `codexU` / `codexu-tauri` 及其 WebView2 子进程计数为 0。
- 下一步：检查阶段一参考驱动和仓库脚本约定，把原生采集、窗口尺寸、六界面遍历、截图输出和精确 PID 清理固化为仓库内正式流程。
- Tasks 中的 agent 使用记录已经验收通过，阶段二不安排相关产品 UI 改造。

### 阶段二：正式采集入口实现

- **状态：** in_progress
- TDD RED：先增加 `windows/scripts/tests/Test-NativeVisualCaptureWorkflow.ps1`，首次运行按预期因正式入口不存在而失败。
- 首次 GREEN 尝试发现当前 Codex 进程环境未设置 `OS` 环境变量；已改为使用 `.NET` 的 `Environment.OSVersion.Platform` 判断 Windows，避免依赖可选环境变量。
- 首次完整入口运行在启动 app 前失败：helper compiler 误选了 `UnionMetadata/Facade/Windows.WinMD`，导致 `Windows.Graphics.Capture` 与 Universal API Contract 类型不可用。以最新版本化 `UnionMetadata/<SDK>/Windows.winmd` 做单变量复现后编译退出码为 0，确认根因。
- 同次调查发现 `DateTime.ToString()` 把未转义的 `native-workflow` 后缀当作自定义日期格式字符，造成输出目录后缀变形；尚未创建 app 或截图。
- 修复上述两项后，第二次完整入口的 Tauri release build 通过，但第一个 960×760 实例在截图前因脚本遗漏加载 `NativeVisualCaptureDriver` 类型而失败。失败清理记录中 remaining/mismatch 均为 0，精确任务 app 实际计数为 0；系统中其他 WebView2 进程未被处理。
- 补齐 native driver 并通过预检合同后，第三次完整入口返回 complete：release build 通过、12 个 PNG 生成、两个 client size 精确复读、Tab/Panel 取景记录完整、任务进程清理为 0。
- 逐图检查时 960×760 Tasks 的 `detail=original` 首次预览只显示标题栏；像素采样和 `detail=high` 二次复核确认原 PNG 内容完整，故不修改 helper 首帧策略。
- 第三次运行的实际阻断是 960×760 Skills 横向偏移，以及 DPI-unaware sizing 使 720×540 组只得到 724×587 物理帧并出现水平滚动条/内容露出不足；需改为 DPI-aware 逻辑 client 换算、renderer 横向归零和更有内容的紧凑取景。
- 增加 DPI scaling 合同并修复后，诊断运行恢复两组逻辑客户区对应的高 DPI 物理帧，960×760 Skills 横向偏移消失，紧凑 Tasks 与 Projects 的内容露出明显改善。
- 诊断集逐图检查发现紧凑 Usage 为追求图表露出而累计滚动过深，最终帧未保留选中 Tab。新增“Tab 与 Panel 一旦同处客户区即停止滚动”的 RED 合同并完成 GREEN 修复，避免平滑滚动队列继续把 Tab 推出画面。
- 首次默认复跑完成 release 构建、12 张采集和进程清理，但逐图发现“立即停止”让 960×760 AI Leadership/Usage 内容深度退化，因此未作为最终验收集。
- 进一步将合同改为每次滚轮后等待 650ms 落定，再追求首选 Tab 高度或识别真实页尾；合同先 RED 后 GREEN。`-SkipBuild` 诊断复跑的 12 张已逐张通过，重点 720×540 Projects 同帧显示选中 Tab 与多条完整项目行。

### 阶段二完成状态

- **状态：** complete
- 最终使用无参数正式入口重新执行 release 构建与原生采集，返回 `complete`：2 个窗口尺寸、6 个表面、12 张原始 PNG，`final_process_cleanup` 为 `confirmed`。
- Agent 已逐张查看最终运行 12 张原图的等比例本地审阅副本；布局/层级、卡片和列对齐、长文本、等待/空态、图表/列表、滚动、紧凑取景和真实数据口径均在实际出现范围内通过。终态错误未在本次真实快照中出现，未声称覆盖。
- 最终进程复核：manifest 每组 remaining/mismatch 均为 0；记录进程身份仍存活 0；精确 release app 实例 0。
- 验证结果：
  - 正式入口默认 release 构建与采集：通过，12 张。
  - PowerShell 语法：2 个脚本通过。
  - PowerShell 预检合同：通过。
  - Web production build：通过，保留既有 chunk-size warning。
  - Web 合同测试：6/6 通过。
  - Rust workspace tests：49 通过、1 个需认证本机 CLI 的集成 case ignored。
  - 配对报告关键结论一致性、本地产物 Git ignore、`git diff --check` 与未跟踪文件空白扫描：通过。
- 已生成一致的 `WINDOWS_NATIVE_VISUAL_WORKFLOW_REPORT.md` / `.html`；未嵌入或链接真实截图、日志、本机产物明细或真实产品数值。
- 未创建或切换 worktree；未修改产品 UI、数据读取、评分、缓存或 IPC；未 commit、未 merge、未 push。

## 会话：2026-08-01

### 阶段 3：全屏六表面复核与模块修复

- **状态：** in_progress
- 用户要求全屏结果同样覆盖六个表面，并明确指出 Tasks 全屏布局肉眼可见有问题；允许按问题模块建立独立 session 修复。
- 核对当前 checkout 仍为 `codex/windows-visual-capture-demo` / `934d9e395efabab2694ba5cce97c83db0bae87c9`，既有未提交范围保持不变，启动前精确 release app 进程为 0。
- 扩展 Git 忽略目录内的一次性全屏驱动，成功生成 Overview、Tasks、AI Leadership、Usage、Projects、Skills 六张 2560×1368 原图及审阅副本。
- 第一次命令执行器超时后，脚本仍完成截图与 finally 清理；精确 release app 最终为 0。manifest 记录一个 WebView2 PID 身份变化，未关闭不匹配进程，remaining 为空。
- 下一步：每两张图查看后更新 `findings.md`，完成模块问题归类，再按独立模块分派修复 session。

## 2026-08-01 阶段三：Tasks 首轮修复与视觉否决

- Tasks 实现 session 完成首轮 RED→GREEN；独立审查发现标题区只有最多两行、没有稳定高度，fix round 1 增加 `min-h-10` 与对应契约后通过复审。
- 过程中一次将 TypeScript 非空断言误写入 `.mjs` 导致 JavaScript 语法错误，已在观察正常 RED 前修正。
- Web 全合同、前端构建、PowerShell 工作流契约/预检、Rust workspace 与 Tauri release 构建均通过。
- 首轮修复后全屏六图成功采集且进程完全清理；检查首对 Overview/Tasks 时发现标题省略号，与“不隐藏 Tasks 文本”边界冲突，已否决该轮图像作为最终证据。
- 当前进入第二轮 TDD：契约改为标题必须完整换行显示，不得使用 `line-clamp`/`truncate`；保留状态 footer 与最小两行高度。

## 2026-08-01 阶段三完成：Tasks 修复与全屏六图

- 第二轮 RED→GREEN 完成：标题契约要求 `break-words`、`min-w-0`、`min-h-10`，并明确禁止标题 `line-clamp`、`truncate` 和 `text-ellipsis`；状态每卡片只出现一次且仅位于 footer。
- 独立复审结论：规范符合性 PASS，代码质量 PASS，无 Critical/Important finding；保留一项非阻塞 Minor：源码正则契约对 JSX/class 顺序较敏感。
- 最终验证：Web 合同 7/7，前端 production build 通过；PowerShell 正式入口语法、工作流合同与 preflight 通过；Rust workspace 49 通过、1 个需认证本地 CLI 用例按设计 ignored；Tauri release 构建通过。
- 最终全屏采集：同一 release 实例按精确 HWND 生成 Overview、Tasks、AI Leadership、Usage、Projects、Skills 六张原生 PNG，manifest 为 complete，六图尺寸一致。
- 人工验收：Tasks 长标题完整换行、状态 footer 分离、四列顶部对齐；AI Leadership/Usage/Projects/Skills 无布局、图表、列表或空状态回归。
- 进程清理：manifest 无 remaining 和 identity mismatch；事后只读复核为精确 release app 0、匹配隔离 runtime 命令行 0。
- 已更新 Markdown/HTML 配对报告；报告不嵌入或链接真实截图、日志、本地路径明细或真实产品数值。未 commit、未 merge、未 push。
- `git diff --check` 最终通过；同时对 11 个未跟踪任务文件执行未跟踪空白诊断，未发现尾随空白或空白错误；Markdown/HTML 关键结论一致性与禁止产物链接检查通过。
