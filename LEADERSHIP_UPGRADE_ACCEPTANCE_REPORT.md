# AI Leadership 真实链路验收报告（Windows）

日期：2026-07-26  
路径：Windows `codexu-tauri` + `codexu-core`

## 1. 结论（先说结果）
- 已完成从 stub 到真实聚合链路：`LeadershipDashboardSnapshot.model_version` 从 `"1.3-stub"` 升级为 `"1.4-real"`（非 stub）。
- `windows/crates/codexu-core/src/readers/common.rs` 中新增真实聚合（token + delta + 日期窗口 + 项目/并发/趋势归集），并补齐后端单测。
- `windows/apps/codexu-tauri/web/src/components/LeadershipPanel.tsx` 增加了模型版本包含 `stub` 的横幅提示。
- 已完成本地验证：`cargo test -p codexu-core`、`cargo build`、`npm run build` 全部通过。
- 仍有“降级字段”但不再是“stub 全空”：
  - 主要目标字段（score/core_score/title/dimensions/maturity/evidence_coverage/active_day_count/ai_hours/autonomous_hours/average_parallelism/peak_concurrency/daily_points/projects）都有返回逻辑；
  - 无数据时部分字段按“明确降级”返回 0/空集合（而非 stub 占位空壳）。

## 2. 参考自 mac baseline 对齐说明
基于 `Sources/CodexUsageWidget/Domain/LeadershipModel.swift` 与 `Services/LeadershipDataReader.swift` 的实现特征，mac 侧已明确有这几个验收结构：
- 4 维度：`span / leverage / orchestration / autonomy`
- 28 天窗口的 `dailyPoints`
- 项目榜单 `projects`
- `score`、`core score`、`title`、`maturity`、`evidence_coverage` 与 `activeDayCount`
- 低置信度/不可证据化路径会降级处理（mac 偏保守，会返回空/N/A 或 `nil`）。

Windows 当前实现保持相同字段结构，并在缺失时提供可解释的 fallback（详见 4.）。

## 3. 验收功能清单（逐项）

| 项目 | 目标 | 验证状态 |
|---|---|---|
| 模型版本升级 | `model_version` 不再包含 `stub` | ✅ PASS（`1.4-real`） |
| `score` | 非空，或无数据有明确降级行为 | ✅ PASS（有数据时一定有值；有测试覆盖） |
| `core_score` | 非空，或有明确降级行为 | ✅ PASS |
| `title` | 非空，或有明确降级行为 | ✅ PASS |
| `dimensions` | 至少 4 个维度 | ✅ PASS（固定 4） |
| `maturity` | 有定义值 | ✅ PASS |
| `evidence_coverage` | 有定义值 | ✅ PASS（0~1） |
| `active_day_count` | 有定义值 | ✅ PASS |
| `ai_hours` | 有定义值（无数据返回 0） | ✅ PASS |
| `autonomous_hours` | 有定义值或明确降级 | ⚠️ 条件 PASS（有事件时返回；无事件时返回 null） |
| `average_parallelism` | 有定义值或明确降级 | ✅ PASS（无数据时返回 0） |
| `peak_concurrency` | 有定义值或明确降级 | ✅ PASS（无数据时返回 0） |
| `daily_points` | 至少有 28-day 数据点 | ✅ PASS（固定长度 28） |
| `projects` | 有数据时返回至少 1 条项目贡献 | ✅ PASS（有数据测试覆盖） |
| stub 提示条 | 当 `model_version` 包含 stub 时 UI 显示“占位/引擎未接入” | ✅ PASS（前端已实现） |

## 4. 剩余降级（fallback）字段清单

> 这里的“fallback”是指“无有效数据时的降级值”，并非返回空结构。

| 字段 | 降级策略 | 当前行为 |
|---|---|---|
| `autonomous_hours` | 无事件时无可计算依据 | 可能返回 `null` |
| `projects` | 无可用 project/event 时 | 返回空数组 `[]` |
| `score/core_score/title` | 活跃度与证据不足时 | 会按可计算式返回低档可读值（最低层级），而不是完全 `null` |
| `dimensions` | 无可计算指标时 | 会返回 4 个有权重/得分的维度（低值而非空） |
| `active_day_count/ai_hours/average_parallelism/peak_concurrency` | 无活动时 | 返回 0 |

## 5. 关键日志（验收证据）

### 5.1 cargo test
`cargo test -p codexu-core`
```
running 9 tests
... passed 9 tests
test readers::common::tests::builds_real_leadership_snapshot_from_usage ... ok
test readers::common::tests::preserves_empty_fallback_when_no_delta_points ... ok
...
test result: ok. 9 passed; 0 failed; 0 ignored
```

### 5.2 cargo build
`cargo build`
```
Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.41s
```

### 5.3 web build
`npm run build`（Windows Web）
```
✓ 2394 modules transformed.
✓ built in 2.48s
dist/index.html ...
```

## 6. 关键截图 / 说明
- 当前环境为命令行/构建验证环境，未附带可交付的 UI 截图文件；如需，我可以再补一个本地截图清单（按运行时界面截取）：
  1) 访问 AI Leadership 面板；
  2) 确认 score/maturity/4 维度卡片；
  3) 确认 28-day trend 列表有 daily points；
  4) 确认项目贡献至少 1 项（有数据场景）。

## 7. 改动文件清单
1. `windows/crates/codexu-core/src/readers/common.rs`
   - 替换 `build_stub_leadership_snapshot` 为真实聚合链路 `build_leadership_snapshot`
   - 新增字段归并、时段点、维度计算与降级逻辑
   - 新增单元测试 2 条（有数据/空数据）
2. `windows/apps/codexu-tauri/web/src/components/LeadershipPanel.tsx`
   - 新增 `model_version` 命中 `stub` 时的提示 Banner
   - 文案：`当前为占位/引擎未接入`

## 8. 说明与待办
- 代码已提交至本地 git（见下节）。
- 若你要我继续，我可以再补一条 **UI 运行时截图验收脚本/流程**，直接对你本机执行并回填截图路径。
