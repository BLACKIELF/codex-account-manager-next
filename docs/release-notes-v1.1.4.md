# codexU v1.1.4

这是一次修复 Codex 账户与额度数据显示失败的稳定 patch。v1.1.2 引入的 Foundation 定长 pipe 读取会等待 app-server stdout 凑满 64 KiB；由于初始化与额度响应通常只有几百字节且长连接不会主动关闭，codexU 最终在 12 秒后超时并显示“Codex 账户接口暂不可用”。

## 主要更新

- app-server stdout 改用 POSIX `read(2)`：只要有数据就立即返回，不再等待填满固定长度缓冲区。
- 额度一次性读取和今日任务长连接统一使用同一套部分响应读取语义。
- 每次读取仍限制为 64 KiB，总缓冲限制为 1 MiB，并保留请求超时、EOF、终止和强制清理路径。
- 新增 writer 保持打开时的小响应读取与 EOF 回归测试，发布包装会强制执行。
- 全局内存风险门禁会阻断 app-server 重新使用 Foundation 定长 pipe 读取。
- 保持本地优先和隐私边界：不新增网络请求、遥测或用户数据上传。

## 验证

- 实际 Codex app-server 探测恢复为 `quotaReadSucceeded=true`，账户及额度窗口正常返回且无错误消息。
- 通过完整构建、POSIX pipe、额度、任务、Claude Skill、解析器和 macOS 兼容性自测。
- 通过全局内存风险门禁及旧 Foundation 读取模式的负向阻断测试。
- 通过 Apple Silicon 与 Intel 双架构 DMG、checksum、挂载、Mach-O 架构和 codesign 验证。

## 安装包

- 内部构建号：23。
- Apple Silicon：`codexU-1.1.4-mac-arm64.dmg`
- Intel：`codexU-1.1.4-mac-x86_64.dmg`

## SHA-256

```text
6f303f68010d8b95d7098252177c489bdc4b0795ee4c452cfe3575bb777e9779  codexU-1.1.4-mac-arm64.dmg
3c799ed82da7ef4ad170896bac1c54ee344390b566389ef181f2caf1fd631efd  codexU-1.1.4-mac-x86_64.dmg
```

本次安装包使用仓库默认签名流程构建，未执行 Apple notarization。
