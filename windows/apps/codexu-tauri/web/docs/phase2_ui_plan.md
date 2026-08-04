# Windows Tauri UI 阶段计划

## 当前范围

- 目标：在 Windows Tauri 界面继续对齐 macOS 交互结构，先保证主功能闭环，再逐步细化视觉还原。
- 约束：按阶段提交，phase2 完成后再进入下一阶段 review。

## Phase 2：主 UI 结构重建（mac 交互优先）

### 目标

- 以 macOS 的结构为优先：顶部工具栏 + 标签分区 + 内容卡片化。
- 优化主信息入口的可用性，不改变现有数据链路。

### 验收要求（本阶段）

- 顶部状态区域继续显示用量和刷新状态。
- 增加 `Overview / AI Leadership / Threads / Projects` 四个 Tab。
- Tab 切换不影响已存在数据加载/刷新流程。
- `AI Leadership` tab 能正确展示 `LocalUsage.leadership` 的可见内容（若无则显示空态）。
- 运行构建 `web` 不报类型错误。

## Phase 3：AI 领导力可视化增强（后续）

- 在 `AI Leadership` 下增加更完整的指标解释、趋势和项目贡献说明。
- 给出得分解释（score path / 维度权重 / 置信度说明）。

## Phase 4：交付收尾（后续）

- 完成回归验证、体验收口、最终阶段 review 与 release 检查清单。

