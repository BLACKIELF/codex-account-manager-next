# Phase 2：Codex RuntimeProvider（当前）

在 Phase 1 基础上读取 `state_5.sqlite` 补充线程元数据：

- 线程标题、项目路径、模型、归档状态、Git 信息
- SQLite 读取失败时自动降级为 JSONL-only
- 标题自动截断到 200 字符，避免保存完整 prompt

## 快速开始

Windows 工作区使用 MSVC ABI。首次在当前检出目录开发时，安装并设置项目级 toolchain override：

```powershell
rustup toolchain install 1.97.1-x86_64-pc-windows-msvc --profile minimal --component rustfmt
rustup override set 1.97.1-x86_64-pc-windows-msvc
```

该 override 只作用于当前 `windows/` 目录，不修改全局默认 toolchain。仓库不提交
`rust-toolchain.toml`，因为只写版本号时，rustup 会沿用用户的 default host，在配置为
GNU 的 Windows 环境中意外选择 GNU ABI，并额外要求系统提供 `dlltool.exe`。

```powershell
cd windows
cargo build --release

# 使用默认路径（~/.codex/state_5.sqlite）
$env:RUST_LOG="info"
.\target\release\codexu-probe.exe --summary

# 指定 Codex 数据根
.\target\release\codexu-probe.exe --codex-root "$env:USERPROFILE\.codex" --summary
```

## 验证

```powershell
# Rust workspace tests
cargo +stable-x86_64-pc-windows-msvc test --workspace
```

### 原生视觉验收

Dashboard 的正式 Windows 本机采集入口会构建真实 Tauri release 应用，并执行一次
最大化、exact HWND 的采集运行。Overview 仅采集一个顶部 viewport；Tasks、AI Leadership、
Usage 与 Skills 使用动态编号的 panel segments；Projects 仅采集一个最大化的首个 viewport。
采集实例保持最大化，但以 non-activating background tool window 运行：不改变用户当前前台窗口，
并从任务栏和 Alt-Tab 排除；正常启动 codexU 的窗口行为不变。
截图、日志和 WebView2 临时数据只写入
Git 忽略的 `.local-artifacts/`；当前契约不包含额外的 client sizes。

测试分三层：

1. `-PreflightOnly` 只检查依赖、脚本语法、窗口策略和输出边界，不构建、不启动窗口。
2. `Test-NativeVisualCaptureWorkflow.ps1` 检查采集 workflow 的静态契约，包括最大化、non-activating、保留前台窗口、后台 Z-order、tool window、任务栏/Alt-Tab 排除和精确 capture 参数。
3. `Test-NativeVisualCaptureCoverage.ps1` 构建并启动真实 Tauri release 应用，覆盖各 Dashboard surface，验证 exact HWND、真实截图、前台窗口未改变和最终进程清理。

```powershell
cd ..

# 不启动 app 的快速检查
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\Capture-NativeVisuals.ps1 -PreflightOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualCaptureWorkflow.ps1

# 真实窗口覆盖测试（会构建、启动、截图并清理）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\tests\Test-NativeVisualCaptureCoverage.ps1

# 正式采集
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\Capture-NativeVisuals.ps1

# 只采集 Skills 的聚焦运行
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\scripts\Capture-NativeVisuals.ps1 -Surface Skills
```

Coverage 运行速度不是当前验收重点；重点是它不会抢焦点或覆盖用户正在使用的窗口。运行边界、DPI 说明、精确 PID 清理规则和人工验收清单见
[`docs/windows-port/WINDOWS_NATIVE_VISUAL_WORKFLOW.md`](../docs/windows-port/WINDOWS_NATIVE_VISUAL_WORKFLOW.md)。

## 工程结构

```text
windows/
├── Cargo.toml
├── README.md
└── crates/
    ├── codexu-core/
    │   ├── Cargo.toml
    │   └── src/
    │       ├── lib.rs
    │       ├── models/
    │       │   ├── mod.rs
    │       │   ├── usage.rs
    │       │   ├── runtime.rs
    │       │   └── leadership.rs
    │       └── readers/
    │           ├── mod.rs
    │           ├── common.rs              ← 聚合、缓存、成本估算
    │           ├── codex_state.rs         ← 新增：state_5.sqlite 读取
    │           ├── codex_transcript.rs    ← Codex JSONL + 元数据富化
    │           └── claude_transcript.rs   ← Claude Code JSONL（保留，待激活）
    └── codexu-cli/
        ├── Cargo.toml
        └── src/
            └── main.rs                    ← CLI 入口
```

## 下一步

进入 Phase 4：Windows UI（跳过 Phase 3 Claude Code provider）。
