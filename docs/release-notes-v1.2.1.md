# codexU v1.2.1

这是一次修复 AI 领导力启动崩溃并完善 Codex 模型用量趋势的稳定 patch，对应 [Issue #39](https://github.com/shanggqm/codexU/issues/39)。

## 主要更新

- 修复领导力等级尚未生成、但今日已有 Agent 记录时，指挥半径 Canvas 因零轨道参与节点布局而触发 `SIGTRAP` 连续崩溃的问题。
- 零轨道状态现在会跳过 Agent 节点绘制，并新增“无等级但已有 Agent”回归断言，覆盖 Issue #39 的触发条件。
- Codex 用量趋势新增模型活动概览与按模型面积图，支持 30、60、90、180 天范围和全局总量虚线。
- 模型趋势按 Top 8 + 其他模型聚合，可在 token 与 API 等效估算费用之间切换；缺少专属价格时明确标注使用 GPT-5.5 参考价格。
- 优化模型图例、行样式和 tooltip 信息层级；Claude Code 暂不支持模型归因时保留清晰降级说明。
- 保持本地优先和隐私边界：不新增遥测，不上传 usage、线程、路径、日志或账户数据。

## 验证

- 通过 Issue #39 零轨道 / 非零 Agent 回归断言、AI 领导力模型自测、模型用量趋势自测和全部既有发布自测。
- 通过全局内存风险门禁，并人工复核 Process、Pipe、Timer、Observer、文件读取、静态集合和父路径上溯风险清单。
- 通过 Apple Silicon 与 Intel 双架构 DMG、checksum、挂载、Mach-O 架构和 codesign 验证。
- 通过 `git diff --check`、Info.plist 校验和发布元数据检查。

## 安装包

- 内部构建号：26。
- Apple Silicon：`codexU-1.2.1-mac-arm64.dmg`
- Intel：`codexU-1.2.1-mac-x86_64.dmg`

## SHA-256

```text
a3877ab66a47e6059f5b8f71913a13fe7a1f2775879dd1cd80c566fd3f0d14d8  codexU-1.2.1-mac-arm64.dmg
e857f6d148fe12f97c43ca246ec6ed54ee590a7653e418519b154daa2a6c8aff  codexU-1.2.1-mac-x86_64.dmg
```

本次安装包使用仓库默认 ad-hoc 签名流程构建，未执行 Apple notarization。
