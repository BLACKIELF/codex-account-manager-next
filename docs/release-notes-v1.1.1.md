# codexU v1.1.1

这是一次聚焦任务可信度、额度兼容和本地体验的稳定 patch 更新。今日任务现在严格区分“最近活动”和“仍在执行”，Codex Team 月额度与 Claude Code Skill 路径也获得了更完整的本地兼容。

## 主要更新

- 今日任务按事实源自适应：Codex 展示“最近活跃、待继续、定时、今日归档”，Claude Code 使用本地 task 的显式状态；归档不等于成功，近期活动不等于仍在运行。
- 任务卡片优先展示标题、工作区、事实时间和可信状态；支持整卡打开 Codex Session、hover、手型指针和键盘焦点，同时移除无行为图标与低价值单字母标识。
- Codex automation 可解析常见日/周 RRULE 和 IANA 时区，并在信息足够时显示下次运行；缺时区或不支持规则不会生成猜测时间。
- 新增 Codex Team 月额度窗口识别和菜单栏剩余额度表达，兼容月额度字段别名、不同窗口拓扑和缺失数据降级。
- Claude Code Skill 路径可从个人、项目、嵌套、插件和旧版 command 目录本地回退定位，并补充静态 Token/字节估算与跨来源去重。
- 主窗口可在 820–1280pt 范围内调整宽度并恢复上次尺寸；额度重置明细统一支持悬停查看。
- 增加隐私安全的本地性能采样、阶段验收门禁和项目级 Skill 统一目录，不新增遥测、远程上传或用户内容展示。

## 验证

- 通过任务运行时、Codex Session Deep Link、额度归一化、Claude Skill 路径、性能监控、阶段门禁、Token 统计、配色和 macOS 兼容性自测。
- 通过 Apple Silicon 与 Intel 双架构 DMG、checksum、挂载、Mach-O 架构和 codesign 验证。

## 安装包

- 内部构建号：20。
- Apple Silicon：`codexU-1.1.1-mac-arm64.dmg`
- Intel：`codexU-1.1.1-mac-x86_64.dmg`

## SHA-256

```text
4d76632da16381aa762869ba1142d5a7390c960d02a2a7b0c22cd218686b1950  codexU-1.1.1-mac-arm64.dmg
df2f5af207e9ef2cc0f771dff227e3bc7a6247cf766364b9fe3f145bebe7d916  codexU-1.1.1-mac-x86_64.dmg
```

本次安装包使用仓库默认签名流程构建，未执行 Apple notarization。
