# Phase 0：Windows 数据路径调研蓝图

## 一、阶段架构图

![调研阶段架构图](docs/windows-port/roadmap/phase-0-research/diagram.png)

---

## 二、阶段目标

在不读取敏感线程正文的前提下，确认 Windows 上 Codex / Claude Code 的数据：

1. **在哪里** —— 数据根目录和文件路径
2. **有没有** —— `state_5.sqlite`、JSONL、tasks、automation 等关键文件
3. **一不一样** —— SQLite 表结构、JSONL 字段名是否与 macOS 一致
4. **能不能用** —— `codex app-server` 或等价 API 是否可用

---

## 三、调研工具

### 3.1 `probe.ps1`

PowerShell 7 脚本，功能：

- 扫描候选 Codex 数据根目录：`%USERPROFILE%\.codex`、`%LOCALAPPDATA%\Codex`、`%APPDATA%\Codex`
- 扫描候选 Claude Code 数据根目录：`%USERPROFILE%\.claude`、`%APPDATA%\Claude`、`%LOCALAPPDATA%\Claude`
- 检查 `state_5.sqlite` 是否存在
- 用 `sqlite3 .schema` 检查表结构是否匹配 macOS 参考
- 抽取 JSONL 前 5 行的字段名（不读取值）
- 检查 JSONL 是否有 UTF-8 BOM
- 检查 `codex app-server` 是否可用
- 输出结构化 `findings.yaml`

### 3.2 人工补充

脚本跑完后，需要人工确认：

- Codex / Claude Code 在 Windows 上的安装方式（CLI / 桌面应用 / WSL？）
- 是否需要启用某些实验性功能才会生成数据文件
- 官方文档是否声明 Windows 支持

---

## 四、交付物

| 文件 | 用途 |
|---|---|
| [`probe.ps1`](./probe.ps1) | 自动探测脚本 |
| [`findings.yaml`](./findings.yaml) | 结构化调研结果（脚本自动生成） |
| [`RESEARCH.md`](./RESEARCH.md) | 调研说明与决策记录 |

---

## 五、决策门

根据 `findings.yaml` 的 `recommendation` 字段：

- **GO** → 进入 [`phase-1-core-prototype/`](../phase-1-core-prototype/)
- **CAUTION** → 进入 phase 1，但缩小范围（例如只做 Codex，先不做 Claude Code）
- **STOP** → 在 Windows 上安装/运行 Codex CLI 后再重新探测
- **DEFER** → 等待官方 Windows 支持

---

## 六、隐私约束

- 不读取线程标题、prompt、回复正文
- 不读取账户信息、token、API key
- JSONL 样例只提取字段名
- SQLite 只读取 `.schema`
- `findings.yaml` 可以安全地贴到 GitHub issue 中
