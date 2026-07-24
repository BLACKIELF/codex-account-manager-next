# Phase 0：Windows 数据路径与格式调研

> 目标：确认 Windows 上 Codex / Claude Code 的数据位置、文件格式是否与 macOS 一致。  
> 原则：不读取敏感线程正文，只探测路径、文件列表、表结构和 JSONL 字段样例。

---

## 一、需要验证的问题

### 1.1 Codex on Windows

| 问题 | 验证方法 | 状态 |
|---|---|---|
| Codex CLI / 桌面应用是否支持 Windows？ | 查看 OpenAI 官方文档或执行 `codex --version` | 待验证 |
| Windows 上 Codex 数据根目录在哪里？ | 运行 [`probe.ps1`](./probe.ps1) | 待验证 |
| 是否存在 `state_5.sqlite`？路径是什么？ | 文件系统扫描 | 待验证 |
| `state_5.sqlite` 表结构是否与 macOS 一致？ | `sqlite3 .schema` 或 Rust probe | 待验证 |
| 是否存在 `sessions/**/*.jsonl` 和 `archived_sessions/*.jsonl`？ | 文件系统扫描 | 待验证 |
| JSONL 事件类型是否与 macOS 一致？（`token_count`、`task_started`、`task_complete`） | 样例行检查 | 待验证 |
| 是否存在 `automations/**/automation.toml`？ | 文件系统扫描 | 待验证 |
| Windows 上是否有 `codex app-server` 或等价本地 API？ | 执行 `codex app-server --help` 或端口扫描 | 待验证 |
| JSONL 文件编码是否为 UTF-8？是否有 BOM？ | 十六进制查看文件头 | 待验证 |

### 1.2 Claude Code on Windows

| 问题 | 验证方法 | 状态 |
|---|---|---|
| Claude Code 是否有 Windows 原生版本？ | 查看 Anthropic 官方文档 | 待验证 |
| Windows 上 Claude Code 数据根目录在哪里？ | 运行 [`probe.ps1`](./probe.ps1) | 待验证 |
| 是否存在 `~/.claude/projects/**/*.jsonl`？ | 文件系统扫描 | 待验证 |
| 是否存在 `~/.claude/tasks/**/*.json`？ | 文件系统扫描 | 待验证 |
| 是否存在 `~/.claude.json` 全局状态文件？ | 文件系统扫描 | 待验证 |
| transcript JSONL 字段是否与 macOS 一致？（`message.usage`、`tool_use`、`attribution`） | 样例行检查 | 待验证 |
| statusLine snapshot 在 Windows 上如何生成？ | 需要 Claude Code 运行并观察缓存目录 | 待验证 |

---

## 二、探测脚本使用说明

在 Windows PowerShell 中运行：

```powershell
# 设置 UTF-8 输出
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# 运行探测脚本
.\docs\windows-port\roadmap\phase-0-research\probe.ps1
```

脚本会：
1. 扫描常见 Codex / Claude Code 数据路径
2. 列出找到的文件和目录
3. 检查 `state_5.sqlite` 是否存在
4. 抽取少量 JSONL 样例行（仅字段名，不输出值）
5. 检查 JSONL 是否有 UTF-8 BOM
6. 输出结构化发现到 `findings.yaml`

---

## 三、macOS 参考路径

作为对照，macOS 上 codexU 读取的路径：

```text
~/.codex/state_5.sqlite
~/.codex/sqlite/state_5.sqlite
~/.codex/sessions/**/rollout-*.jsonl
~/.codex/archived_sessions/*.jsonl
~/.codex/automations/**/automation.toml

~/.claude/projects/**/*.jsonl
~/.claude/tasks/**/*.json
~/.claude.json
~/Library/Caches/codexU/claude-code/statusline-snapshot.json
```

Windows 上可能的对应路径：

```text
%USERPROFILE%\.codex\state_5.sqlite
%LOCALAPPDATA%\Codex\state_5.sqlite
%USERPROFILE%\.codex\sessions\**\rollout-*.jsonl
%USERPROFILE%\.codex\archived_sessions\*.jsonl
%USERPROFILE%\.codex\automations\**\automation.toml

%USERPROFILE%\.claude\projects\**\*.jsonl
%USERPROFILE%\.claude\tasks\**\*.json
%USERPROFILE%\.claude.json
%LOCALAPPDATA%\codexU\claude-code\statusline-snapshot.json
```

---

## 四、关键发现记录格式

调研结果写入 [`findings.yaml`](./findings.yaml)：

```yaml
codex:
  supported: true/false
  data_root: "%USERPROFILE%\\.codex"
  state_5_sqlite:
    exists: true/false
    path: "..."
    schema_matches_macos: true/false/unknown
  sessions_jsonl:
    exists: true/false
    pattern: "..."
    event_types: ["token_count", "task_started", "task_complete"]
    has_bom: true/false
  automations:
    exists: true/false
    pattern: "..."
  app_server:
    available: true/false
    notes: "..."

claude_code:
  supported: true/false
  data_root: "%USERPROFILE%\\.claude"
  transcripts:
    exists: true/false
    pattern: "..."
    fields: ["message", "usage", "tool_use", "attribution"]
    has_bom: true/false
  tasks:
    exists: true/false
    pattern: "..."
  global_state:
    exists: true/false
    path: "..."
  statusline_snapshot:
    exists: true/false
    path: "..."
    notes: "..."

risk_assessment:
  - "..."

recommendation: "进入阶段 1 / 调整范围 / 停止"
```

---

## 五、安全与隐私

- 不读取线程标题、prompt、回复正文。
- 不读取账户信息、token、API key。
- JSONL 样例只提取字段名和类型，不提取值。
- SQLite 只读取 `.schema`，不读取 threads 表内容。
- 所有输出文件可以安全地贴到 GitHub issue 中。

---

## 六、下一步

1. 在 Windows 上安装 Codex CLI / Claude Code（如果尚未安装）。
2. 运行 `probe.ps1`。
3. 将 `findings.yaml` 填入实际结果。
4. 根据风险评估决定：
   - **低风险** → 进入 [`phase-1-core-prototype/`](../phase-1-core-prototype/)
   - **中风险** → 调整阶段 1 范围（例如只实现 Codex）
   - **高风险** → 停止或等待官方 Windows 支持
