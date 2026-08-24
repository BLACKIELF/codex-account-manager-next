# codexU v1.1.3

这是一次针对 macOS 13 内存与 CPU 异常的稳定 patch。Claude Skill 项目路径解析在旧版 Foundation 下可能越过文件系统根目录并不断生成 `/..` 链，导致启动刷新无法完成、CPU 长时间占满且常驻内存持续增长；本版本修复了这条路径。

## 主要更新

- Claude Skill 项目路径到达 `/` 时立即停止上溯，不再依赖不同 macOS 版本对 `deletingLastPathComponent()` 的返回行为。
- 增加 visited 路径集合，即使 Foundation 返回循环父路径也会安全退出。
- 补充 macOS 13 根目录父路径异常的合成回归测试，并覆盖从 `/` 查找不存在 Skill 的终止行为。
- 全局内存风险门禁新增父路径上溯、根目录终止、循环去重和回归断言检查；发布包装会强制执行 Claude Skill 路径自测。
- 保持本地优先和隐私边界：不新增网络请求、遥测或用户数据上传。

## 验证

- 通过 Claude Skill 路径回归自测、全局内存风险门禁及门禁负向阻断测试。
- 通过完整构建、macOS 兼容、解析器、统计时区、Token、状态栏、额度、粒子动画和更新检测自测。
- 通过 Apple Silicon 与 Intel 双架构 DMG、checksum、挂载、Mach-O 架构和 codesign 验证。

## 安装包

- 内部构建号：22。
- Apple Silicon：`codexU-1.1.3-mac-arm64.dmg`
- Intel：`codexU-1.1.3-mac-x86_64.dmg`

## SHA-256

```text
1577cb8d2cf3c0a0280031a9bd9f895bdfa6aae8ce4252fd8aa2b6880183e46b  codexU-1.1.3-mac-arm64.dmg
9af5962605dbb1c9227235a651158de9827eeb3a428dfa7740f9c23df547f9c9  codexU-1.1.3-mac-x86_64.dmg
```

本次安装包使用仓库默认签名流程构建，未执行 Apple notarization。
