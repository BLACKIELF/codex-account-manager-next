# codexU v1.1.2

这是一次针对 macOS 13 内存稳定性的 patch 更新。它修复 app-server 输出、请求和子进程生命周期中的无界增长路径，并为本地会话解析、进程输出与缓存补齐明确上限。

## 主要更新

- app-server 长连接改用有背压的有界读取，单次只保留 1 MiB 接收缓冲；任务列表请求限制为单个在途请求并增加 10 秒超时。
- EOF、断连和超时统一关闭 pipe、终止子进程，必要时强制清理；stderr 直接重定向，避免未消费的错误输出阻塞或累积。
- Codex 与 Claude Code transcript 改为分块流式解析，超大记录会被跳过；进程输出、Skill 文件、会话缓存和持久缓存均增加字节或条数上限。
- 发布流程新增全局内存风险门禁，扫描全部生产 Swift 源码中的无界 FileHandle/Process/Pipe、Timer 生命周期、缓存及观察者清理风险；未通过时 `release-package` 和 `release-check` 都会阻断。
- 保持本地优先和隐私边界：不新增遥测，不上传 usage、线程、路径、日志或账户数据。

## 验证

- 通过全局内存风险门禁、任务运行时、性能监控、额度、解析器、统计时区、Token、状态栏、粒子动画、更新检测和 macOS 13 兼容性自测。
- 使用约 4.9 GB 本地 Codex 数据进行冷/热缓存探测；冷缓存峰值约 274 MiB，热缓存峰值约 171 MiB，均完成且未出现无界增长。
- 通过失效 app-server socket 故障注入，常驻内存进入稳定区间，没有随重连持续增长。
- 通过 Apple Silicon 与 Intel 双架构 DMG、checksum、挂载、Mach-O 架构和 codesign 验证。

## 安装包

- 内部构建号：21。
- Apple Silicon：`codexU-1.1.2-mac-arm64.dmg`
- Intel：`codexU-1.1.2-mac-x86_64.dmg`

## SHA-256

```text
620494769edddd03034ddef9b970a1f5db7509362c801a082d6fe4e88c8f4aa6  codexU-1.1.2-mac-arm64.dmg
ac1db501031e762eef8de59dffddf41fe9c11baa0ac11dd2a1b1a91a9d3b5e17  codexU-1.1.2-mac-x86_64.dmg
```

本次安装包使用仓库默认签名流程构建，未执行 Apple notarization。
