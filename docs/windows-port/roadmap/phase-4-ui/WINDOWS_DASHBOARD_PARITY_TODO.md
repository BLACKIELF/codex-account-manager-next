# Windows Dashboard Parity TODO（阶段分支前置）

> 目标：为下一分支 `codex/windows-dashboard-lower-panels` 形成可执行待办，不作功能交付承诺。
> 不改产品代码、数据模型、IPC、截图资产，且不新增 README 变更。

## 任务定位与证据边界

- `macOS` 参考：
  - 固定概览（leadership/用量/羊毛）来源：`Sources/CodexUsageWidget/main.swift:4057-4113`
  - 五个变体页签定义：`tasks / leadership / usage / projects / skills`，对应：`Sources/CodexUsageWidget/main.swift:3880-3884`
  - 页签切换与内容插槽逻辑：`Sources/CodexUsageWidget/main.swift:4122-4148`
- 当前 `Windows` 现状：
  - `Dashboard` 默认顶层有固定顶部与 L1-L7 进度。
  - 全局主导航目前为 `Dashboard / AI Leadership / Usage / Threads / Projects`。

## 总体约束

- 只在现有前端数据契约内实现视图重组，**不改 Reader / cache / IPC / thread parser**。
- 对缺失字段一律用真实空态（如 `Record insufficient`）而非推断、补齐或假设。
- 每一项 TODO 必须具备：
  - 状态：`ready frontend` / `blocked data contract` / `decision needed`
  - 作用域
  - No-go 边界
  - 验收标准
  - 预期验证方式

## TODO 列表

- **TODO-01：重构 Windows Dashboard 骨架为固定上方 + 下方 4 格切换**
  - 状态：`ready frontend`
  - 作用域：将 dashboard 主页固定区域定义为：
    - 上方固定区（Leadership 摘要、7 日 token mix、Today/7-Day/Lifetime）
    - 下方四格可变区（Tasks / Usage / Projects / Skills）
  - No-go 边界：
    - 不改 `useUsage()` 的返回体
    - 不改导航模型之外的数据源
  - 验收标准：
    - macOS 有五个页签；Windows 目标为“固定头 + 4 下方插槽”（Leadership 为固定明细）
    - Leadership 明细保持 `AI Leadership` 明细入口（不是第 5 个下方面板）
  - 预期验证：
    - 结构性复核（手工 UI 审视）
    - 代码 diff 限定到 dashboard 视图组合与路由/tab 显示逻辑
    - `git diff --check`

- **TODO-02：复用并迁移现有 Usage/Projects 面板到下方插槽**
  - 状态：`ready frontend`
  - 作用域：将现有 Usage 与 Projects 的展示组件复用到下部插槽，不重复开发新卡片；保留现有入口语义。
  - No-go 边界：
    - 不新增计算型字段
    - 不替换图表/统计口径
  - 验收标准：
    - Usage/Projects 下方卡片可见且可切换
    - 963px 及以下（如有）保留可访问导航和可用顺序，不出现布局丢失
  - 预期验证：
    - 响应式检查（最窄关键断点）
    - 键盘可达性（Tab 顺序/焦点可达）
    - `git diff --check`

- **TODO-03：Today 任务盘**
  - 状态：`blocked data contract`
  - 作用域：明确 Today 任务盘的实现边界：当前 Windows 数据仅提供 Today token 与 recent threads 指标，缺少任务状态模型，无法直接映射 `tasks`。
  - No-go 边界：
    - 禁止以 threads 伪造任务卡
    - 禁止更改线程解析逻辑（需另行授权与契约）
  - 验收标准：
    - 文档中明确“数据缺失时不呈现虚拟任务状态”
    - TODO 标记为阻塞，不混入“完成”状态
  - 预期验证：
    - 数据字段核对（现有 `usage` / `detailed usage` / `recent threads`）
    - 任务板签出待办卡状态（blocked）

- **TODO-04：Skills 面板**
  - 状态：`blocked data contract`
  - 作用域：记录 Windows web 层当前未暴露/消费按类型的 skills 使用字段；仅允许占位声明。
  - No-go 边界：
    - 不改 reader/cache/IPC，不新增 skills 聚合 pipeline
    - 不产出“未采集字段”的假值
  - 验收标准：
    - 明确界定 Skills 仍缺失
    - 待能力开放后新增后再行实现
  - 预期验证：
    - 代码/类型审阅确认 `models.ts` 中没有可直接驱动的 typed skills usage 字段

- **TODO-05：月度羊毛进度（Month progress）与 API 限额对齐**
  - 状态：`decision needed`
  - 作用域：确认 Windows 中“Month 估值”口径是否可作为 macOS “Token mix / monthly progress”对照口径。
  - No-go 边界：
    - 不能直接将 monthly/monthly wool 与 Token mix 等同
    - 不能把估算值标为 official rate-limit
  - 验收标准：
    - 形成决议条目（继续对齐/不对齐/需新口径）
    - 若继续对齐，文档明确差异：窗口显示上限与定价口径不同
  - 预期验证：
    - 口径评审（产品、数据、工程）
    - 决议写入本 TODO 与后续分支说明

- **TODO-06：视觉证据更新时机**
  - 状态：`decision needed`
  - 作用域：明确：本轮不补真实截图证据，仅在 UI 与交互验证通过后再补充新的 Windows 原生截图和 showcase 对齐条目。
  - No-go 边界：
    - 不用旧图片代替当前状态
    - 不纳入本轮“完成”统计
  - 验收标准：
    - 仅在 native build + manual acceptance 后更新 `docs/windows-port/showcase` 与 parity 报告配图
    - 证据文件与章节映射一一对应（Today / Skills 未实现，Usage 与 Projects 为 partial 形态）
  - 预期验证：
    - build/启动通过后人工 native 截图抽样复核
    - `git diff --check`

- **TODO-07：分支与提交顺序**
  - 状态：`ready frontend`
  - 作用域：采用固定执行顺序：
    1. 先提交当前“证据边界 + 对齐TODO”文档
    2. 再开 `codex/windows-dashboard-lower-panels` 分支执行 UI 重构
    3. 分支内继续补齐实现与截图后再提 PR
  - No-go 边界：
    - 不提前把 TODO 作为实现进度
    - 不混入与 dashboard 不相关代码
  - 验收标准：
    - 分支名与目标一致
    - TODO 文档提交独立可回放
  - 预期验证：
    - `git status --short`（确认本轮仅含本待办两文件）
    - 分支策略记录在 PR 描述/变更说明中

## 输出格式要求（本 TODO）

- Markdown 与 HTML 结论必须一致（状态、阻塞项、边界、验收口径一致）。
- 任何页面级比较一律标注“证据边界”，不得将“未采集字段”直接归类为“功能缺失证明”。
- 后续若新增信息补齐源头字段，应在该 TODO 中新增新状态项，不覆盖旧阻塞记录。

## 依赖文件清单（本轮不改动）

- `Sources/CodexUsageWidget/main.swift`（结构参考）
- `windows/apps/codexu-tauri/web/src/components/DashboardHome.tsx`（现有 Windows 固定 top）
- `windows/apps/codexu-tauri/web/src/types/models.ts`（类型边界）
- `docs/windows-port/showcase/MACOS_WINDOWS_FEATURE_COMPARISON.md/html`
