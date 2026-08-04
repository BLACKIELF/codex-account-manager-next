# Phase 1：跨平台核心读取原型蓝图

## 一、阶段架构图

![Phase 1 架构图](docs/windows-port/roadmap/phase-1-core-prototype/diagram.png)

---

## 二、阶段目标

实现一个命令行工具 `codexu-probe`，能够读取 Codex 本地 session JSONL，输出与 macOS `codexU --dump-json` 兼容的 `LocalUsage` JSON。

Claude Code provider 因 Windows 上尚未出现 `~/.claude/projects/**/*.jsonl` 数据路径，本阶段标记为 **deferred**，待数据路径确认后再实现/验证。

---

## 三、模块定义

| 模块 | 职责 | 输入 | 输出 |
|---|---|---|---|
| `CodexTranscriptReader` | 扫描、缓存、解析 Codex session JSONL | `~/.codex/archived_sessions/*.jsonl` / `~/.codex/sessions/**/*.jsonl` | `LocalUsage` |
| `ClaudeCodeTranscriptReader` | （deferred）扫描、缓存、解析 Claude Code transcript | `~/.claude/projects/**/*.jsonl` | `LocalUsage` |
| `readers::common` | 与 runtime 无关的聚合逻辑 | provider 解析后的 delta | `LocalUsage` |
| `Domain Models` | 与 macOS 同构的数据模型 | 原始 JSONL 事件 | 聚合后的用量对象 |
| `codexu-probe` | 命令行入口 | 用户指定的路径 | `codexu-probe.json` |
| `session-usage-v1.json` | 文件指纹缓存 | 解析后的 summary | 下一次读取时复用 |

---

## 四、数据契约

输出 JSON 的根对象必须是 [`LocalUsage`](../../windows/crates/codexu-core/src/models/usage.rs) 结构。

关键字段：

```json
{
  "lifetime_tokens": 1234567,
  "today_tokens": 12345,
  "seven_day_tokens": 98765,
  "thread_count": 42,
  "detailed_usage": { ... },
  "usage_trend": { ... },
  "project_board": { ... },
  "tool_usages": [ ... ]
}
```

---

## 五、Codex JSONL 格式映射

Codex session JSONL 的顶层字段只有三个：

```json
{
  "timestamp": "2026-03-26T12:53:47.164Z",
  "type": "event_msg",
  "payload": { ... }
}
```

macOS 上期望的字段需要到 `payload` 对象里找：

| 语义 | Codex 位置 |
|---|---|
| 会话 ID | `session_meta.payload.id` |
| 工作目录 / 项目路径 | `session_meta.payload.cwd` / `turn_context.payload.cwd` |
| 模型 | `turn_context.payload.model` |
| 用量 | `event_msg.payload.type == "token_count"` 下的 `info.last_token_usage` |
| 工具调用 | `response_item.payload.type == "custom_tool_call"` 下的 `name` |

注意：`info.last_token_usage` 是当前 turn 的增量；`info.total_token_usage` 是会话累计值，聚合时必须使用增量，否则会重复计算。

---

## 六、关键设计选择

1. **只读本地文件**：不上传任何数据。
2. **文件指纹缓存**：按文件大小 + 修改时间纳秒判断是否重新解析。
3. **流式读取**：避免大 JSONL 文件占用过多内存。
4. **与 macOS 模型同构**：方便后续 UI 复用同一套 JSON。
5. **Codex-first**：当前 Windows 上只有 Codex 数据可用，Claude Code provider 先保留实现但默认不启用。

---

## 七、验证方式

1. 在 Windows 上运行 Codex 一段时间（已满足）。
2. 执行 `codexu-probe.exe`。
3. 检查输出 JSON 的 token 数、项目、工具调用是否合理。

示例：

```powershell
.\target\release\codexu-probe.exe --summary
```

---

## 八、当前状态

- [x] Rust workspace 初始化
- [x] Domain 模型翻译
- [x] `readers::common` 共享聚合逻辑
- [x] `CodexTranscriptReader` 实现
- [x] `codexu-probe` CLI 默认 Codex provider
- [x] 在真实 Windows Codex 数据上编译验证
- [ ] Claude Code provider 待数据路径出现后再验证

---

## 九、下一步

验证 Codex provider 稳定后，进入 [`phase-2-codex-provider/`](../phase-2-codex-provider/) 读取 `state_5.sqlite` 元数据以补充 project / thread 信息，并视情况激活 Claude Code provider。
