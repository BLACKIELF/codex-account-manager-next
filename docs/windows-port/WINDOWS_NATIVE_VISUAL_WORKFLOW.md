# Windows 原生视觉采集与人工验收

本文档描述 Windows Dashboard 的正式本机视觉验收流程。验收对象是当前 checkout 构建出的真实 Tauri release 应用、真实 WebView2、真实窗口装饰与 DPI，以及只读的真实本地 Codex 输入。

该流程不使用 Computer Use、Playwright、fixture、浏览器 mock、baseline 或 pixel diff，也不替代 Rust、Web 合同测试和 release build。

## 运行命令

从仓库根目录运行完整验收：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\Capture-NativeVisuals.ps1
```

只检查依赖、尺寸/表面合同和本地产物边界，不构建、不启动 app、不创建输出目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\Capture-NativeVisuals.ps1 -PreflightOnly
```

默认入口会从 `windows/` 执行：

```text
cargo +stable-x86_64-pc-windows-msvc tauri build --no-bundle
```

只有在同一 checkout 的 release executable 已由本次开发者明确验证时，才可用 `-SkipBuild` 做调试采集；正式验收记录必须使用默认构建路径。

## 采集行为

一次完整运行按以下顺序执行：

1. 验证 Windows、Cargo、Git、UI Automation、.NET C# compiler 与 Windows SDK metadata。
2. 验证输出是 `.local-artifacts/windows-visual-captures/` 下尚不存在的目录，并确认 Git ignore 生效。
3. 将仓库内的 Windows Graphics Capture helper 源码编译到本次本地产物目录。
4. 构建真实 Tauri release 应用。
5. 拒绝接管已经运行的同一精确 release executable。
6. 依次启动 960×760 和 720×540 两个任务实例；每种尺寸只保留一个实例。
7. 设置并重新读取 client area，记录 DPI 与原生外框尺寸。
8. 用 UI Automation 选择 Tasks、AI Leadership、Usage、Projects、Skills；Overview 使用页面顶部状态。
9. 滚动消息只发送给当前任务 app 的 renderer HWND。每次滚轮后等待 WebView2 平滑滚动落定，再优先把选中 Tab 移到客户区上半部；到达真实页尾时，在 Tab/Panel 仍同帧的前提下停止。Projects 不使用固定深滚动量。
10. Windows Graphics Capture 按任务 app 的精确主 HWND 采集窗口帧。
11. 每个尺寸完成或发生失败/中断时，清理并复核本任务记录的精确 app/WebView2 PID 身份。

## 本地产物

默认输出位于：

```text
.local-artifacts/windows-visual-captures/<timestamp>-native-workflow/
├── manifest.json
├── screenshots/
│   ├── 960x760/
│   │   ├── overview.png
│   │   ├── tasks.png
│   │   ├── ai-leadership.png
│   │   ├── usage.png
│   │   ├── projects.png
│   │   └── skills.png
│   └── 720x540/
│       └── 同一组 6 张截图
├── logs/
├── runtime/
└── tools/
```

这些目录包含真实截图、运行日志、WebView2 临时数据、进程记录和本机路径，只能保存在 `.local-artifacts/`。不得提交、上传、复制进公开报告，也不得从报告链接。

真实 Codex 输入只读使用。任务 app 的 `APPDATA`、`LOCALAPPDATA` 与 WebView2 user-data folder 指向本次 `runtime/`，但用户目录下的 Codex 数据源不被复制或修改。

## 窗口尺寸与 DPI

- 目标 client area 固定为 960×760 与 720×540。
- 脚本通过 Win32 client/window rect 设置并复读尺寸；不以截图像素猜测 client area。
- Windows Graphics Capture 输出包含原生窗口装饰，物理帧会随 DPI scaling 改变，因此通常大于 client area。
- `manifest.json` 记录 requested client、verified client、outer window、DPI 与每张图的 physical frame；人工验收只比较本次记录，不建立 baseline。

## 进程边界与清理

- 启动前若同一精确 release executable 已经运行，脚本立即失败，不关闭该实例。
- 每个任务实例记录 app 与其后代进程的 PID、父 PID、创建时间、名称和 executable identity。
- 清理前再次核对记录身份；PID 已被复用或身份不匹配时不关闭该进程，并把结果记入本地 manifest。
- 正常完成、异常和 Ctrl+C 中断都经过 `finally` 清理路径。
- 验收结束必须同时满足：精确任务 app 为 0、记录的任务 WebView2 子进程为 0、manifest 中 `final_process_cleanup` 为 `confirmed`。

## 逐表面人工验收清单

每次正式运行必须逐张打开 12 张新图，不复用旧图。不要在公开记录中抄写真实文本、路径、PID、数值或截图文件名明细。

| 表面 | 960×760 与 720×540 必查项 |
|---|---|
| Overview | Header 与主次层级清楚；领导力、额度、本地指标和下方 Tab 导航关系可辨；并列卡片基线、边距与边框一致；缺失/等待值没有伪造成 0；估算口径可辨。 |
| Tasks | 选中 Tab 与任务内容同帧；列/卡片层级稳定；真实 agent 用量/活动文本在卡片内正常换行；空列或暂无记录状态清楚；没有水平溢出。 |
| AI Leadership | 选中 Tab 与详情内容同帧；周期、等级进度、四项指标、图表/项目贡献的先后层级可辨；徽章、卡片、轨道与图例不互相遮挡；缺失证据使用明确降级状态。 |
| Usage | 选中 Tab 与图表同帧；图表标题、轴、图例、tooltip 入口和汇总卡关系清楚；列表/图表不被裁切；本地估算与官方额度语义不混淆。 |
| Projects | 选中 Tab 与项目列表/详情同帧，尤其检查 720×540；项目行、数值列、相对条形与工具摘要对齐；长名称/尾路径不突破容器；滚动后仍能判断所属 Tab。 |
| Skills | 选中 Tab 与列表或无记录状态同帧；列表行层级、图标、名称和辅助信息稳定；空态明确；长名称不会造成卡片或页面横向溢出。 |

每张图还需统一检查：

- 布局与信息层级。
- 并列卡片、标题栏、列表行和图表对齐。
- 长文本换行、截断与容器边界。
- 当前真实数据中实际出现的空、等待或错误状态；未出现的状态不得声称已验证。
- 图表、图例、轴、列表和滚动连续性。
- 紧凑尺寸下选中 Tab 与对应内容是否同帧可辨。
- 官方数据、本地记录、本地估算和记录不足是否使用正确口径。

## 验证命令

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualCaptureWorkflow.ps1

$scripts = @(
  '.\windows\scripts\Capture-NativeVisuals.ps1',
  '.\windows\scripts\tests\Test-NativeVisualCaptureWorkflow.ps1'
)
foreach ($script in $scripts) {
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path $script),
    [ref]$tokens,
    [ref]$parseErrors
  )
  if ($parseErrors.Count -gt 0) { $parseErrors; exit 1 }
}

cd .\windows
cargo +stable-x86_64-pc-windows-msvc test --workspace

cd .\apps\codexu-tauri\web
npm run build
$testFiles = (Get-ChildItem .\tests\*.test.mjs).FullName
node --test $testFiles

cd ..\..\..\..
git diff --check
```

## 已知限制

- 结果只证明本次 checkout、当前真实数据和当前 Windows/DPI 环境。
- 流程不建立像素基准，不自动判断视觉优劣；最终结论来自逐张人工检查。
- 只验收 Overview 与五个 Dashboard Tab，不覆盖主题矩阵、系统菜单、dialog 或未实际出现的终态错误。
- Windows Graphics Capture helper 需要可用的 D3D11、Windows SDK metadata 与 .NET Framework C# compiler。
