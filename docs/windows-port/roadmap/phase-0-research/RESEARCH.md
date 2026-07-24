# Phase 0：Windows 数据路径与格式调研

> 目标：确认 Windows 上 Codex / Claude Code 的数据位置、文件格式是否与 macOS 一致。  
> 原则：不读取敏感线程正文，只探测路径、文件列表、表结构和 JSONL 字段样例。  
> 状态：**已完成**（2026-07-24）

---

## 一、需要验证的问题

### 1.1 Codex on Windows

| 问题 | 验证方法 | 状态 | 结果 |
|---|---|---|---|
| Codex CLI / 桌面应用是否支持 Windows？ | 执行 `codex --version` / `codex app-server --help` | ✅ 已验证 | `codex app-server --help` 返回正常，本地 API 可用 |
| Windows 上 Codex 数据根目录在哪里？ | 运行 [`probe.ps1`](./probe.ps1) / [`probe_py.py`](./probe_py.py) | ✅ 已验证 | `%USERPROFILE%\.codex` |
| 是否存在 `state_5.sqlite`？路径是什么？ | 文件系统扫描 | ✅ 已验证 | `C:\Users\ADMIN\.codex\state_5.sqlite` |
| `state_5.sqlite` 表结构是否与 macOS 一致？ | `sqlite3 .schema` | ✅ 已验证 | 包含 `threads`、`rollout_path`、`thread_spawn_edges`，与 macOS 一致 |
| 是否存在 `sessions/**/*.jsonl` 和 `archived_sessions/*.jsonl`？ | 文件系统扫描 | ✅ 已验证 | 两者均存在；活跃 sessions 在 `sessions\2026\03\04\rollout-*.jsonl`，archived 在 `archived_sessions\*.jsonl` |
| JSONL 事件类型是否与 macOS 一致？（`token_count`、`task_started`、`task_complete`） | 样例行检查 | ⚠️ 部分一致 | 顶层字段仅 `payload`、`timestamp`、`type`，具体事件类型需解析 `payload` |
| 是否存在 `automations/**/automation.toml`？ | 文件系统扫描 | ✅ 已验证 | 存在 3 个：`check-cc-switch-issue-4885`、`opengu-daily-log`、`travel-map` |
| Windows 上是否有 `codex app-server` 或等价的本地 API？ | 执行 `codex app-server --help` | ✅ 已验证 | 可用，输出与实验性 CLI 一致 |
| JSONL 文件编码是否为 UTF-8？是否有 BOM？ | 十六进制查看文件头 | ✅ 已验证 | UTF-8，无 BOM |

### 1.2 Claude Code on Windows

| 问题 | 验证方法 | 状态 | 结果 |
|---|---|---|---|
| Claude Code 是否有 Windows 原生版本？ | 查看 Anthropic 官方文档 / 实际运行 | ✅ 已验证 | 已安装并可运行，数据根为 `%USERPROFILE%\.claude` |
| Windows 上 Claude Code 数据根目录在哪里？ | 运行 [`probe.ps1`](./probe.ps1) / [`probe_py.py`](./probe_py.py) | ✅ 已验证 | `%USERPROFILE%\.claude` |
| 是否存在 `~/.claude/projects/**/*.jsonl`？ | 文件系统扫描 | ✅ 已验证 | 存在，样例：`projects\E--project-agent-for-planning\33c97a49-...jsonl` |
| 是否存在 `~/.claude/tasks/**/*.json`？ | 文件系统扫描 | ❌ 未找到 | 当前未创建任务 |
| 是否存在 `~/.claude.json` 全局状态文件？ | 文件系统扫描 | ✅ 已验证 | `C:\Users\ADMIN\.claude.json` |
| transcript JSONL 字段是否与 macOS 一致？（`message.usage`、`tool_use`、`attribution`） | 样例行检查 | ✅ 已验证 | 顶层字段包含 `message`、`message.content`、`message.role`、`timestamp`、`type` 等，结构一致；`message.usage` 需进一步出现确认 |
| statusLine snapshot 在 Windows 上如何生成？ | 需要 Claude Code 运行并观察缓存目录 | ⚠️ 待观察 | 预期路径 `%LOCALAPPDATA%\codexU\claude-code\statusline-snapshot.json` 尚未生成 |

---

## 二、探测脚本使用说明

在 Windows PowerShell 7 中运行原脚本：

```powershell
# 设置 UTF-8 输出
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# 运行探测脚本（需要 PowerShell 7）
.\docs\windows-port\roadmap\phase-0-research\probe.ps1
```

如果环境只有 PowerShell 5.1 或 Bash，可运行等价的 Python 版本：

```bash
cd docs/windows-port/roadmap/phase-0-research
python probe_py.py
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

Windows 上的实际对应路径：

```text
%USERPROFILE%\.codex\state_5.sqlite
%USERPROFILE%\.codex\sessions\**\rollout-*.jsonl
%USERPROFILE%\.codex\archived_sessions\*.jsonl
%USERPROFILE%\.codex\automations\**\automation.toml

%USERPROFILE%\.claude\projects\**\*.jsonl
%USERPROFILE%\.claude\tasks\**\*.json
%USERPROFILE%\.claude.json
%LOCALAPPDATA%\codexU\claude-code\statusline-snapshot.json
```

> 注：本次探测未发现 `%LOCALAPPDATA%\Codex` 或 `%APPDATA%\Codex` 数据根，实际数据根为 `%USERPROFILE%\.codex`。

---

## 四、关键发现记录格式

调研结果写入 [`findings.yaml`](./findings.yaml)：

```yaml
codex:
  supported: true
  data_root: "C:\\Users\\ADMIN\\.codex"
  state_5_sqlite:
    exists: true
    path: "C:\\Users\\ADMIN\\.codex\\state_5.sqlite"
    schema_matches_macos: true
    schema_notes: schema matches macOS reference
  sessions_jsonl:
    exists: true
    pattern: "C:\\Users\\ADMIN\\.codex\\sessions\\**\\rollout-*.jsonl"
    sample_path: "C:\\Users\\ADMIN\\.codex\\sessions\\2026\\03\\04\\rollout-2026-03-04T02-09-15-019cb4e3-d4b4-7331-bda4-6d0630ea6c88.jsonl"
    event_types: []
    all_fields: ["payload", "timestamp", "type"]
    has_bom: false
  automations:
    exists: true
    pattern: "C:\\Users\\ADMIN\\.codex\\automations\\**\\automation.toml"
  app_server:
    available: true
    notes: "[experimental] Run the app server or related tooling..."

claude_code:
  supported: true
  data_root: "C:\\Users\\ADMIN\\.claude"
  transcripts:
    exists: true
    pattern: "C:\\Users\\ADMIN\\.claude\\projects\\**\\*.jsonl"
    sample_path: "C:\\Users\\ADMIN\\.claude\\projects\\E--project-agent-for-planning\\33c97a49-0eac-4734-9ac2-251d449c23e8.jsonl"
    fields:
      - attachment
      - cwd
      - entrypoint
      - gitBranch
      - isSidechain
      - isSnapshotUpdate
      - message
      - message.content
      - message.role
      - messageId
      - parentUuid
      - permissionMode
      - promptId
      - promptSource
      - sessionId
      - snapshot
      - timestamp
      - type
      - userType
      - uuid
      - version
    has_bom: false
  tasks:
    exists: false
    pattern: "C:\\Users\\ADMIN\\.claude\\tasks\\**\\*.json"
  global_state:
    exists: true
    path: "C:\\Users\\ADMIN\\.claude.json"
  statusline_snapshot:
    exists: false
    path: "C:\\Users\\ADMIN\\AppData\\Local\\codexU\\claude-code\\statusline-snapshot.json"
    notes: Run Claude Code with codexU integration to generate

risk_assessment: []
recommendation: "GO: Enter phase-1-core-prototype. Consider deferring Claude Code provider if its data is missing."
```

> 完整字段清单以 [`findings.yaml`](./findings.yaml) 为准。

---

## 五、重要发现与风险

1. **Codex 数据路径与 macOS 高度一致**：`%USERPROFILE%\.codex` 对应 `~/.codex`，`state_5.sqlite` 表结构一致，`app-server` 可用。
2. **Codex JSONL 顶层字段较简**：活跃 sessions 的 JSONL 顶层只有 `payload`、`timestamp`、`type`，macOS 上期待的 `token_count`、`task_started`、`task_complete` 等事件类型可能封装在 `payload` 对象内部，phase-1 需要解析 `payload`。
3. **automations 确实存在**：`opengu-daily-log`（每日）、`travel-map`（每周一）、`check-cc-switch-issue-4885`，`automation.toml` 结构与 macOS 设计一致。
4. **Claude Code 数据也存在**：transcripts 字段结构与 macOS 预期一致；tasks 未找到，statusline snapshot 未生成，均非 phase-1 阻塞项。
5. **编码安全**：JSONL 均为 UTF-8 无 BOM，可直接用 Rust/Python 标准库读取。

---

## 六、安全与隐私

- 不读取线程标题、prompt、回复正文。
- 不读取账户信息、token、API key。
- JSONL 样例只提取字段名和类型，不提取值。
- SQLite 只读取 `.schema`，不读取 threads 表内容。
- 所有输出文件可以安全地贴到 GitHub issue 中。

---

## 七、下一步

Phase 0 已完成，建议：

1. **进入 [`phase-1-core-prototype/`](../phase-1-core-prototype/)**：用 Rust 实现最小 CLI，读取 Codex/Claude Code 数据并输出 JSON。
2. **Phase 1 优先关注**：
   - Codex `state_5.sqlite` 读取与 threads 枚举。
   - Codex JSONL 中 `payload` 的事件类型解析。
   - Claude Code transcript JSONL 的 `message` 解析。
3. **延后到 Phase 2/3**：
   - automation 的 RRULE 与下次运行时间计算。
   - Claude Code `tasks/*.json` 与 statusline snapshot。
4. 更新 [`RFC.md`](../../RFC.md) 中的调研清单状态。
