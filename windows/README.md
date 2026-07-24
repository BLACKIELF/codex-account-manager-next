# Phase 2：Codex RuntimeProvider（当前）

在 Phase 1 基础上读取 `state_5.sqlite` 补充线程元数据：

- 线程标题、项目路径、模型、归档状态、Git 信息
- SQLite 读取失败时自动降级为 JSONL-only
- 标题自动截断到 200 字符，避免保存完整 prompt

## 快速开始

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
cargo test -p codexu-core
```

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
