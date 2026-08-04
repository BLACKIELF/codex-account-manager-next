# Phase 2：Codex RuntimeProvider 完整实现

## 一、阶段目标

在 Phase 1 的 JSONL 解析基础上，读取 Codex 的 `state_5.sqlite`，为每个 session/thread 补充元数据：

- 线程标题（`threads.title`）
- 项目路径（`threads.cwd`）
- 模型名称（`threads.model`）
- 是否归档（`threads.archived`）
- 最后更新时间（`threads.updated_at_ms`）
- Git 分支 / 远程地址（`threads.git_branch`, `threads.git_origin_url`）

**本阶段不实现**：
- Claude Code provider（Phase 3，可跳过）
- Automation 的 RRULE 解析与下次运行时间
- `codex app-server` 额度 API 调用
- Windows UI

---

## 二、交付物

```text
docs/windows-port/roadmap/phase-2-codex-provider/
└── BLUEPRINT.md                    ← 本文件

windows/crates/codexu-core/src/readers/
├── codex_state.rs                  ← 新增：state_5.sqlite 读取器
├── codex_transcript.rs             ← 扩展：支持元数据富化
├── claude_transcript.rs            ← 适配：SessionSummary 新字段
├── common.rs                       ← 扩展：SessionSummary 元数据字段 + 标题截断
└── mod.rs                          ← 导出 CodexStateReader / CodexThreadMetadata

windows/crates/codexu-cli/src/main.rs  ← CLI 默认读取 state_5.sqlite
```

---

## 三、关键设计

### 3.1 `CodexStateReader`

- 使用 `rusqlite`（bundled）打开 `%USERPROFILE%\.codex\state_5.sqlite`。
- 查询 `threads` 表，按 `rollout_path` 的 `file_name()` 建立索引。
- SQLite 读取放在 `tokio::task::spawn_blocking` 中，避免阻塞 async runtime。
- 读取失败时整表降级：CLI 继续用 JSONL 原始数据，不崩溃。

### 3.2 元数据匹配键

`state_5.sqlite` 的 `rollout_path` 是绝对路径，例如：

```text
C:\Users\ADMIN\.codex\sessions\2026\03\26\rollout-2026-03-26T20-53-36-019d2a35-18c6-7a91-a1af-ea3f821cd221.jsonl
```

`CodexStateReader` 只取 `file_name()` 作为键，与扫描磁盘得到的 JSONL 文件名匹配。文件名包含时间戳与 UUID，全局唯一，不会冲突。

### 3.3 富化规则

对每个 `CodexTranscriptSummary` 转换为 `SessionSummary` 时：

| 字段 | JSONL 来源 | SQLite 补充规则 |
|---|---|---|
| `project_path` | `session_meta.cwd` / `turn_context.cwd` | SQLite `cwd` 非空时覆盖 |
| `model` | `turn_context.model` | JSONL 缺失时用 SQLite `model` |
| `last_active_at` | JSONL 事件最新时间 / 文件修改时间 | 与 SQLite `updated_at_ms` 取较大值 |
| `title` | 无 | SQLite `title` |
| `archived` | 默认 `false` | SQLite `archived` |
| `git_branch` / `git_origin_url` | 无 | SQLite 对应字段 |

同时，所有 `UsageDelta.project_path` 也会同步为富化后的 `project_path`，保证项目聚合（`project_board`）与线程列表一致。

### 3.4 标题截断

Codex 的 `title` 列通常保存第一条用户消息或生成的摘要，长度可能达到数千字符。`common::truncate_title` 将其截断到 200 字符，避免在 UI/JSON 中保存完整 prompt。

### 3.5 隐私边界

- **读取**：`threads.title`、`cwd`、`model`、`archived`、`updated_at_ms`、`git_branch`、`git_origin_url`。
- **不读取**：`first_user_message`、`preview`、`agent_role` 等可能包含完整线程正文的字段。

---

## 四、验证方式

### 4.1 单测

```powershell
cd windows
cargo test -p codexu-core
```

覆盖：

- `CodexStateReader::load_metadata` 正确解析 `threads` 表。
- 文件名标准化同时支持 Windows 与 Unix 路径。
- `CodexTranscriptReader::load_local_usage_with_metadata` 正确富化标题、路径、模型、归档状态。
- 标题缺失时回退到项目短名。

### 4.2 真实数据验证

```powershell
cd windows
$env:RUST_LOG="info"
.\target\release\codexu-probe.exe --summary
```

检查输出：

- `Loaded metadata for N threads from state DB` 与 `state_5.sqlite` 的 `threads` 行数一致。
- `Projects` 数量合理（空路径不会全部塌陷成 "Codex"）。
- 输出 JSON 中 `recent_threads` 的 `title`、`archived`、`cwd`、`model` 字段均已填充。

---

## 五、运行结果（本机）

在 Windows 11 + Codex CLI 环境下实测：

```text
Codex data root: C:\Users\ADMIN\.codex
Codex state DB:  C:\Users\ADMIN\.codex\state_5.sqlite
Loaded metadata for 559 threads from state DB
Parsed 556 files, 41798 unique usage events
Today: 91756559 tokens, 7-day: 2259273438 tokens, lifetime: 9676800304 tokens
Projects: 111
Tools: 2
```

归档线程数 61，与 `SELECT COUNT(*) FROM threads WHERE archived=1` 一致。

---

## 六、已知限制

- `state_5.sqlite` 可能被正在运行的 Codex 进程锁定；读取失败时自动降级为 JSONL-only。
- `threads.title` 仍可能包含用户消息片段，已截断到 200 字符。
- Windows UNC 路径前缀 `\\?\` 保留，UI 层可再处理显示。
- 尚未实现 automation / task 板 / app-server 额度。

---

## 七、下一步

Phase 2 已完成，下一步按用户要求跳过 Phase 3（Claude Code provider），直接进入 [Phase 4：Windows UI](../phase-4-ui/)。
