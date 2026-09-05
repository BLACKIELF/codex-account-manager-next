# Codex Account Manager Next 0905v2

Release name: `0905v2` · Version: `9.5.2` · Build: `14`

## 与 0905v1 的区别 / Highlights

这次只精简高频选择操作，不改变账号、CLI 或自动化行为。

| Before | After | Why |
| --- | --- | --- |
| 点击模型名，再进入“模型”子菜单 | 点击模型名直接显示模型列表 | 移除没有额外信息的中间层 |
| 点击强度，再进入“思考强度”子菜单 | 点击强度直接显示支持的档位 | 与模型选择保持一致 |

使用原生 inline Picker 保留当前选中标记与键盘导航。共享控件覆盖账号卡、单账号工作台和菜单栏。即时保存、模型兼容性、Standard/Fast、恢复默认、应用到所有账号及后续 CLI 参数保持原样。

其余菜单审查覆盖添加账号、CLI 更多操作、Chrome 资料、Pro 倍率、设置选择器和 macOS 菜单栏。没有发现相同的重复包裹；目录选择、登录方式和安全门禁保留。

## Verification

- Apple Silicon 优化构建（`-O`，macOS 13 部署目标）通过；构建在临时目录完成，未在编译期间删除正在使用的 App。
- `make lint`、25 组纯测试、5 个运行时 PNG 资源校验、macOS 兼容性脚本、plist 校验与严格签名验证通过。
- 全局内存风险门禁通过并已阅读风险面清单：20 处 Process、15 处 Pipe、22 处 Timer、11 处 observer、38 处 Data 读取、0 个静态可变集合候选、13 处父路径上溯。本次只增加 4 行 Picker 样式，不新增这些风险面；结构检查不等于长时间运行测试。
- 原位覆盖既有 `build/CodexAccountManagerNext.app`，运行路径、版本 `0905v2 / 9.5.2 (14)` 和可执行文件摘要已核验，没有新增安装目录。
- 原生界面验收：点击模型名后，第一层直接出现 6 个模型；点击思考强度后，第一层直接出现该模型支持的 6 档，无同名子菜单。分别发送上下方向键和 Escape，取消后原有模型、强度及速度不变。
- 实际点开 CLI 的“更多”菜单，确认目录入口与复制命令均直接呈现；未执行其中动作。菜单层级通过辅助功能树核验，本轮截图服务不可用，未新增截图。

## Runtime boundaries

这次菜单验收不执行真实 CLI 派单、暖号、账号切换、重新登录或飞书通知。不以菜单与纯测试结果声称这些运行链路已经重新验证。未创建 GitHub tag 或公开二进制 Release。

已有的后台刷新和自动化开关保持原样，重新打开 Next 会恢复其正常后台行为。本次未进行 Intel / Windows 构建、macOS 13 真机验证、Apple 公证或长时稳定性测试。

## Previous-version recovery

本地 `release-archives` 只保留上一版 `0905v1 / build 13` 的 App ZIP，不包含账号或凭据数据。较早的 `0904v2 / build 12` ZIP 在核对 [GitHub 备份分支](https://github.com/BLACKIELF/codex-account-manager-next/tree/archive/app-backups) 文件摘要完全一致后移入废纸篓，可恢复。临时解包的旧 App 也已移入废纸篓。

## Checksums

| Artifact | SHA-256 |
| --- | --- |
| Installed 0905v2 Apple Silicon executable | `55f7a0b3bbdbe610e4cacac58f0084a6a07cf94d1e4086ed703c52de3fc609b4` |
| Previous app ZIP, 0905v1 / build 13 | `d30683b18c0cb08e4ff9aa4dbd0c2fbbec941afbc257a06ba88679ec2c03a5c8` |
