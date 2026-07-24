# Phase 1：跨平台核心读取原型蓝图

## 一、阶段架构图

![Phase 1 架构图](docs/windows-port/roadmap/phase-1-core-prototype/diagram.png)

---

## 二、阶段目标

实现一个命令行工具 `codexu-probe`，能够读取 Claude Code 本地 transcript，输出与 macOS `codexU --dump-json` 兼容的 `LocalUsage` JSON。

---

## 三、模块定义

| 模块 | 职责 | 输入 | 输出 |
|---|---|---|---|
| `ClaudeCodeTranscriptReader` | 扫描、缓存、解析 Claude Code transcript | `~/.claude/projects/**/*.jsonl` | `LocalUsage` |
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

## 五、关键设计选择

1. **只读本地文件**：不上传任何数据。
2. **文件指纹缓存**：按文件大小 + 修改时间纳秒判断是否重新解析。
3. **流式读取**：避免大 JSONL 文件占用过多内存。
4. **与 macOS 模型同构**：方便后续 UI 复用同一套 JSON。

---

## 六、验证方式

1. 在 Windows 上运行 Claude Code 一段时间。
2. 执行 `codexu-probe.exe`。
3. 检查输出 JSON 的 token 数是否与 Claude Code 自身统计接近。

---

## 七、当前状态

- [x] Rust workspace 初始化
- [x] Domain 模型翻译
- [x] `ClaudeCodeTranscriptReader` 实现
- [x] `codexu-probe` CLI 实现
- [ ] 在真实 Windows 数据上编译验证
- [ ] 修复路径/BOM/编码问题

---

## 八、下一步

验证通过后，进入 [`phase-2-codex-provider/`](../phase-2-codex-provider/)。
