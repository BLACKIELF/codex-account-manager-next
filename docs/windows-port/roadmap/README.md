# codexU Windows 版本模块化开发 Roadmap

> 指导原则：**按模块开发，先调研，再 demo，再逐模块扩充。**  
> 每个阶段都有独立的 blueprint、可验证的交付物和明确的"继续/停止"决策点。

---

## 阶段划分

```text
docs/windows-port/roadmap/
├── phase-0-research/        ← 数据路径与格式调研（已完成）
├── phase-1-core-prototype/  ← 跨平台核心读取原型（当前阶段）
├── phase-2-codex-provider/  ← Codex RuntimeProvider 完整实现
├── phase-3-claude-provider/ ← Claude Code RuntimeProvider 完整实现
├── phase-4-ui/              ← Windows 系统托盘 + 主窗口
└── phase-5-packaging/       ← 打包、签名、自动更新
```

---

## 阶段 0：数据路径与格式调研

**目标**：在 Windows 上确认 Codex / Claude Code 的数据是否存在、在哪里、格式是否与 macOS 一致。

**状态**：✅ 已完成（2026-07-24）

**交付物**：
- [`phase-0-research/RESEARCH.md`](phase-0-research/RESEARCH.md) —— 调研报告
- [`phase-0-research/probe.ps1`](phase-0-research/probe.ps1) —— Windows 数据路径探测脚本（PowerShell 7）
- [`phase-0-research/probe_py.py`](phase-0-research/probe_py.py) —— 等价 Python 探测脚本（兼容 Bash/PS5.1）
- [`phase-0-research/findings.yaml`](phase-0-research/findings.yaml) —— 结构化发现清单

**关键结论**：
- Codex 数据路径与 macOS 高度一致：`%USERPROFILE%\.codex` 对应 `~/.codex`。
- `state_5.sqlite` 存在且 schema 与 macOS 一致。
- 活跃 sessions 与 archived sessions JSONL 均存在，顶层字段为 `payload`、`timestamp`、`type`。
- automations 存在 3 个：`opengu-daily-log`、`travel-map`、`check-cc-switch-issue-4885`。
- `codex app-server` 在 Windows 上可用。
- Claude Code 数据根为 `%USERPROFILE%\.claude`，transcripts 存在；tasks 与 statusline snapshot 未生成，可延后。
- JSONL 编码为 UTF-8 无 BOM。

**决策点**：
- ✅ Codex 数据路径和格式与 macOS 高度一致 → **进入阶段 1**

---

## 阶段 1：跨平台核心读取原型

**目标**：用 Rust 实现最小命令行工具，能读取 Codex/Claude 数据并输出与 macOS `--dump-json` 等价的 JSON。

**交付物**：
- [`phase-1-core-prototype/`](phase-1-core-prototype/) —— Rust 工程
- `models/` —— `TokenBreakdown`、`DetailedUsage`、`UsageTrend` 等
- `readers/` —— JSONL 流式读取、SQLite 查询、fingerprint 缓存
- `main.rs` —— CLI：`codexu-probe --output json`

**决策点**：
- CLI 输出与 macOS `--dump-json` 结构一致 → 进入阶段 2
- 不一致 → 调整模型设计

---

## 阶段 2：Codex RuntimeProvider 完整实现

**目标**：实现 Codex 的完整数据读取：SQLite 元数据、JSONL token 事件、automation、app-server / CLI 额度。

**交付物**：
- [`phase-2-codex-provider/`](phase-2-codex-provider/) —— 独立 crate 或模块
- Codex provider 实现
- 单测（用 Windows 上采集的样本数据）

**决策点**：
- Codex provider 能正确输出额度、用量、趋势、任务 → 进入阶段 3 或阶段 4
- 如果 Claude Code Windows 版数据难获取 → 可以跳过阶段 3，先做纯 Codex UI

---

## 阶段 3：Claude Code RuntimeProvider 完整实现

**目标**：实现 Claude Code 的数据读取：transcript JSONL、tasks JSON、statusLine snapshot、global skill usage。

**交付物**：
- [`phase-3-claude-provider/`](phase-3-claude-provider/) —— 独立 crate 或模块
- Claude Code provider 实现
- Skill path resolver 的 Windows 适配

---

## 阶段 4：Windows UI

**目标**：系统托盘 + 弹出菜单 + 主窗口仪表盘 + 设置窗口。

**交付物**：
- [`phase-4-ui/`](phase-4-ui/) —— Tauri 或 WinUI 3 工程
- 复用阶段 1-3 的核心库
- 主窗口：额度环、趋势图、任务板、AI 领导力

---

## 阶段 5：打包、签名与发布

**目标**：MSI/MSIX/便携版 + 自动更新 + GitHub Release。

**交付物**：
- [`phase-5-packaging/`](phase-5-packaging/) —— 打包脚本与 CI
- MSI/NSIS 安装包
- 自动更新检查

---

## 当前阶段：Phase 1

见 [`phase-1-core-prototype/`](phase-1-core-prototype/)，开始实现跨平台核心读取原型。

---

## 与原作者的协作建议

每完成一个阶段，都可以向原仓库提交一次进度更新或 RFC comment：

- Phase 0 完成：提交调研报告 issue，确认数据格式兼容性
- Phase 1 完成：展示 CLI 原型，询问是否愿意未来共享核心算法
- Phase 4 完成：发布 beta 版，邀请 Windows 用户测试

这样即使原作者不参与，也能保持信息透明。
