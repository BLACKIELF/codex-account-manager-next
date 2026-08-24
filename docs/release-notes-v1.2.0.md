# codexU v1.2.0

codexU v1.2.0 全网首推本地 AI 领导力评估模型，把 Codex 与 Claude Code 的 Agent 规模、AI 工时、编排和自主运行转化为可解释的滚动 28 天领导力得分。

## 主要更新

- 合并 Codex 与 Claude Code 的本机 Worker 证据，在同一时间轴上计算去重 Agent、AI 工时、全局峰值并发、父子编排与自主运行。
- 以管理半径、劳动力杠杆、编排能力和自主运行四维生成 0–100 分；时间成熟度抑制单日高并发刷分，独立证据可信度单独披露而不暗改得分。
- 主界面新增“等级徽章 + 指挥半径”第一视觉，2×2 指标矩阵展示领导力分值、近 28 天领导 Agent、AI 工时和峰值并发；轨道节点按今日 Agent 数刷新并封顶 12 个。
- 主窗口聚焦且能耗允许时，分层轨道显示渐变、呼吸外晕与 Agent 公转；失焦、低电量、温控压力或 Reduce Motion 下自动冻结。
- 新增 AI 领导力详情 Tab，以固定 0–100 等级进度、四项核心指标、四维得分、每日 AI 工时/Agent/峰值趋势和项目贡献解释得分。
- 七级中文称号更新为“碳基牛马、赛博监工、分身队长、硅基领主、硅基统帅、超级个体、人类最强者”，并配套 1024×1024 透明 PNG 徽章。
- 七级称号补齐英文映射；等级进度 Title 使用随外观切换的语义文字色，浅色与深色模式均保持可读。
- AI 领导力始终评估 Codex 与 Claude Code 的合计表现，不提供 Runtime 分数筛选，也不简单累加各项目峰值。
- 坚持可信模型边界：成本、交付、主观质量和 Estimated interval 不计分；缺失数据显示记录不足或 `--`，不伪造成 0。
- 修复 AI 领导力 SQLite 查询的进程管道风险，输出增加 32 MiB 总量上限、POSIX 分块读取、stderr 重定向与超限强制清理；AI 领导力与 Claude transcript 磁盘缓存补齐读写字节上限。
- 保持本地优先和隐私边界：不新增遥测，不上传 usage、线程、路径、日志或账户数据。

## 验证

- 通过全局内存风险门禁，人工复核 Process、Pipe、Timer、Observer、文件读取、静态集合和父路径上溯风险清单。
- 通过 AI 领导力模型边界自测、真实本机数据探针、全部既有单元/自测和 `git diff --check`。
- 通过 Apple Silicon 与 Intel 双架构 DMG、checksum、挂载、Mach-O 架构和 codesign 验证。
- 人工验证主界面 28 天 Agent / AI 工时、今日轨道节点、七级徽章和详情趋势布局。

## 安装包

- 内部构建号：25。
- Apple Silicon：`codexU-1.2.0-mac-arm64.dmg`
- Intel：`codexU-1.2.0-mac-x86_64.dmg`

## SHA-256

```text
5645cd34f44c27c65bc6a58a698f42db04996f7551714324ab13e0b004b41a08  codexU-1.2.0-mac-arm64.dmg
b5719142c983dd84deb9f71b19c7d46bbc9529439ecf89034fa70ed3fbca6d54  codexU-1.2.0-mac-x86_64.dmg
```

本次安装包使用仓库默认 ad-hoc 签名流程构建，未执行 Apple notarization。
