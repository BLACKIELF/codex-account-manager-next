# codexU v1.3.0

codexU v1.3.0 新增本机推理性能监测，并补齐 macOS 与 Windows 双平台安装包的自动化发布流程。

## 主要更新

- 新增“推理性能”面板，按模型 × 推理强度展示完整调用的平均耗时、P50、P90、有效吞吐和 reasoning token 占比。
- 支持今日、7 日均和 28 日均三个观察窗口；样本从最近 28 天本机 Codex rollout 回填，并对低于 100ms 的时间戳噪声进行过滤。
- 推理性能历史使用有界去重存储，保存在本机 Application Support；不保存或展示 prompt、回复、路径，也不把指标标为 TTFT 或可见文本解码 TPS。
- 推理性能监测与额度、token、趋势和任务数据路径独立，不改变既有数据口径。
- 发布流程新增 macOS arm64/x86_64 DMG、Windows x86_64 MSI/NSIS 安装包、SHA-256 和跨平台 CI 校验。
- 保持本地优先和隐私边界：不新增遥测，不上传 usage、线程、路径、日志或账户数据。

## 验证

- 通过全局内存风险门禁，并人工复核 Process、Pipe、Timer、Observer、文件读取、静态集合和父路径上溯风险清单。
- 通过推理性能聚合、模型推理性能、模型用量趋势、Token、状态栏、更新检测和 macOS 13 兼容性自测。
- 通过 Apple Silicon 与 Intel 双架构 DMG、checksum、挂载、Mach-O 架构和 codesign 验证。
- Windows x86_64 MSI/NSIS 安装包由 GitHub Actions Windows runner 构建；跨平台资产和 checksum 由 Ubuntu runner 汇总校验。

## 安装包

- 内部构建号：27。
- Apple Silicon：`codexU-1.3.0-mac-arm64.dmg`
- Intel：`codexU-1.3.0-mac-x86_64.dmg`
- Windows MSI：`codexU-1.3.0-windows-x86_64.msi`
- Windows NSIS：`codexU-1.3.0-windows-x86_64-setup.exe`

## SHA-256

```text
7e9663b7518f7f69b81915f6b3c5d02cb3f7adc7b6f46f6fd3d0ca5aa140394c  codexU-1.3.0-mac-arm64.dmg
c07730d89045aa6364c220e64c065b759207ae423c9bf4ce3df4171dffa7e68b  codexU-1.3.0-mac-x86_64.dmg
WINDOWS_MSI_SHA256_PENDING
WINDOWS_NSIS_SHA256_PENDING
```

本次 macOS 安装包使用仓库默认 ad-hoc 签名流程构建，未执行 Apple notarization。Windows 安装包默认未配置代码签名。
