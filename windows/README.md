# Phase 1：跨平台核心读取原型

## 一、阶段目标

实现一个命令行工具 `codexu-probe`，能够：

1. 读取 Claude Code 本地 transcript（`~/.claude/projects/**/*.jsonl`）
2. 解析 `message.usage`、`tool_use`、Skill attribution
3. 使用文件指纹缓存避免重复解析
4. 输出与 macOS `--dump-json` 兼容的 JSON

**本阶段不实现**：
- Codex provider（需要 SQLite，见 phase 2）
- Windows UI
- 系统托盘
- 打包发布

---

## 二、工程结构

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
    │       │   ├── usage.rs      ← TokenBreakdown / LocalUsage / UsageTrend 等
    │       │   ├── runtime.rs    ← RuntimeScope / UsageSnapshot 等
    │       │   └── leadership.rs ← AI 领导力模型
    │       └── readers/
    │           ├── mod.rs
    │           └── claude_transcript.rs  ← Claude Code JSONL 读取器
    └── codexu-cli/
        ├── Cargo.toml
        └── src/
            └── main.rs           ← codexu-probe 命令行入口
```

---

## 三、快速开始

### 3.1 安装 Rust

```powershell
# 使用 rustup
winget install Rustlang.Rustup
# 或访问 https://rustup.rs/
```

### 3.2 编译环境

当前代码使用 Rust 标准库和 `tokio`、`chrono`、`serde` 等常用 crate。由于依赖 `windows-sys`，在 Windows 上构建需要以下工具链之一：

**方案 A：MSVC（推荐，二进制更小）**
```powershell
# 安装 Visual Studio Build Tools 或 Visual Studio Community
# 然后通过 rustup 添加 MSVC target
rustup target add x86_64-pc-windows-msvc
rustup default stable-x86_64-pc-windows-msvc
```

**方案 B：GNU / MinGW-w64**
```powershell
# 安装 MinGW-w64（例如通过 MSYS2 或 winlibs.com）
# 确保 dlltool.exe 和 gcc.exe 在 PATH 中
```

### 3.3 编译

```powershell
cd windows
cargo build --release
```

### 3.4 运行

```powershell
# 使用默认路径
.\target\release\codexu-probe.exe

# 指定 Claude Code 项目路径
.\target\release\codexu-probe.exe --claude-projects "$env:USERPROFILE\.claude\projects"

# 只打印摘要，不写入 JSON
.\target\release\codexu-probe.exe --summary
```

---

## 四、设计说明

### 4.1 模型层

所有模型都是 macOS 版本的直接翻译：

- `TokenBreakdown`：token 拆分
- `PricedTokenUsage`：带估算成本的用量
- `DetailedUsage`：今日/7天/月/累计
- `UsageTrend`：180 天趋势 + 热力图
- `LocalUsage`：聚合后的本地用量
- `LocalThread`、`ProjectUsage`、`ToolUsage`、`SkillUsage`

### 4.2 读取层

`ClaudeCodeTranscriptReader`：

- 递归扫描 `.claude/projects/**/*.jsonl`
- 为每个文件生成 fingerprint（大小 + 修改时间）
- 命中缓存则跳过解析
- 未命中则流式读取文件，解析 usage / tool_use / skill
- 缓存结果到 `%LOCALAPPDATA%\codexU\claude-code\session-usage-v1.json`

### 4.3 CLI

`codexu-probe`：

- 默认读取 `%USERPROFILE%\.claude\projects`
- 默认缓存到 `%LOCALAPPDATA%\codexU`
- 输出 `codexu-probe.json`

---

## 五、验证方式

1. 在 Windows 上安装 Claude Code 并运行一段时间，生成 transcript。
2. 运行 `codexu-probe.exe`。
3. 检查输出 JSON 中的：
   - `today_tokens`
   - `seven_day_tokens`
   - `lifetime_tokens`
   - `project_board`
   - `tool_usages`
4. 与 macOS 版 codexU 的 Claude Code 面板数字对比（允许路径/模型差异）。

---

## 六、已知限制

- 本阶段只支持 Claude Code，不支持 Codex。
- Skill path resolver 未实现，`skill_usages` 为空。
- 估算成本使用内置的 Claude 模型价格（Opus/Sonnet/Haiku），可能与实际订阅不同。
- Windows 路径分隔符和 BOM 处理已考虑，但需真实数据验证。

---

## 七、下一步

阶段 1 验证通过后，进入 [`phase-2-codex-provider/`](../phase-2-codex-provider/)：实现 Codex SQLite + JSONL 读取。
