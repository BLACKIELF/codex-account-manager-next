# codexU v1.1.0

这是一次围绕视觉品质、额度信息完整性和系统兼容性的 minor 更新。codexU 现在提供经过审核的内置配色图库，展示 Codex 可用额度重置次数与到期详情，并正式支持 macOS 13。

## 主要更新

- 新增默认、青花瓷、故宫红、千里江山、敦煌飞天和兰亭晨曦六套稳定配色，统一覆盖 SwiftUI、AppKit、菜单栏、图表、额度环和进度资源。
- 新增独立 Liquid Glass 配色图库，支持浅色/深色即时预览与切换；SVG 图案资源经过白名单校验、缓存和安全回退。
- 社区配色采用受控投稿：仓库提供贡献模板，要求完整来源与许可证信息，并通过生命周期规则、文件布局检查和 CI 渲染验证后才能随应用发布。
- Codex 返回可用额度重置次数时，在额度区域展示总数和最早两条到期信息；悬停可查看完整列表，缺失到期详情会明确说明。
- 最低系统要求降至 macOS 13；在新系统上继续启用 Liquid Glass，并增加打包与条件编译兼容性门禁。
- 修复累计 Token 计数器在字段缺失、辅助计数回退、重复快照和计数器重置时可能重复统计的问题，同时保留 input、cached、output 与 reasoning 拆分。
- 统一设置页与配色图库的玻璃层级、字体、控件栅格和间距。

## 验证

- 通过额度归一化、Token 计数、配色包发现与渲染、状态栏布局及 macOS 13 兼容性自测。
- 通过 Apple Silicon 与 Intel 双架构 DMG、checksum、挂载、Mach-O 架构和 codesign 验证。

## 安装包

- 内部构建号：19。
- Apple Silicon：`codexU-1.1.0-mac-arm64.dmg`
- Intel：`codexU-1.1.0-mac-x86_64.dmg`

## SHA-256

```text
4e4c74abcbd18f0324df3af8853370f42622a82a59c49e90047da45e08b1a4e3  codexU-1.1.0-mac-arm64.dmg
acb1239ddd4aca7e542b278e4b76e68d04bcd65f9563a9b5a1f39ac3c74e1fd6  codexU-1.1.0-mac-x86_64.dmg
```

本次安装包使用仓库默认签名流程构建，未执行 Apple notarization。
