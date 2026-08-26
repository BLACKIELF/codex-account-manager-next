# Codex Account Manager Next

**中文** | [English](README.en.md)

在一台 Mac 上保存和切换多个 Codex 账号，查看官方额度，并在 5 小时额度剩余不高于 5% 或 7 天额度剩余低于 10% 时安全切换到可用备用账号。切换成功或失败后，可以把脱敏结果推送到飞书群。

- 保存、验证、排序和切换多个 Codex 账号。
- 每个账号可绑定现有 Chrome 用户资料；没有匹配资料时自动使用独立、可长期复用的 Chrome 会话。
- 查看官方 5 小时、7 天和月度额度，以及本机 Token、成本、任务和项目统计。
- 5 小时剩余 `<= 5%` 或 7 天剩余 `< 10%` 时，自动选择对应窗口不低于 30% 的备用账号。
- 切换前确认 Codex 没有运行中或等待输入的任务；条件不完整时停止操作。
- 通过飞书自定义机器人接收脱敏的切换结果和异常告警。
- Next 使用独立的 App、数据目录和设置，不覆盖旧版 Codex Account Manager。

> 这不是 OpenAI 官方项目。账号切换会修改当前电脑上的 `~/.codex/auth.json`，并安全退出和重新打开 Codex。自动换号和飞书通知默认关闭，需要你主动启用。

![0826v1 脱敏设置界面](docs/screenshot-0826v1-settings.png)

## 让编程 Agent 帮你安装

你不需要看懂 Swift，也不需要自己处理构建目录。把下面整段话发送给 Codex、Claude Code 或其他能操作本机文件和终端的编程 Agent：

> 请从 https://github.com/BLACKIELF/codex-account-manager-next 安装 Codex Account Manager Next。先询问我希望长期保存源码的位置；如果我需要建议，推荐 `~/Documents/CodexAccountManagerNext`，但不要假设我一定使用这个路径。确认本机是 macOS 13 或更高版本，已经安装 Codex 和 Xcode Command Line Tools，然后克隆或更新仓库并运行 `make build`。构建成功后先执行 README 中列出的账号切换、飞书和签名检查，再把 `build/CodexAccountManagerNext.app` 安装为 `~/Applications/CodexAccountManagerNext.app`，告诉我源码和 App 的准确完整路径。若目标位置已有 Next，请先保留可恢复的备份再替换。不要覆盖、删除或启动旧版 Codex Account Manager；没有我的单独确认，也不要启动 Next、登录账号、切换账号、启用自动化、保存 Webhook 或发送飞书消息。

你的 Agent 应该完成：

1. 确认源码长期保存位置、macOS 版本、Codex 和 Command Line Tools 状态。
2. 从本仓库克隆或更新源码，运行 `make build`，不修改旧版 App。
3. 运行下方列出的纯本地检查，确认构建和关键安全逻辑通过。
4. 把 Next 安装到 `~/Applications/CodexAccountManagerNext.app`；升级时先备份旧的 Next。
5. 告诉你源码、构建产物、已安装 App 的准确路径，以及尚未执行的真实操作。

源码文件夹应长期保留。以后更新时，Agent 需要在同一个目录拉取新版、重新构建并替换 Next App；不要把旧版管理器当成 Next 的更新目标。

## 手动安装

### 需要准备

- macOS 13 或更高版本。
- 已安装并能正常使用的 Codex App 或 Codex CLI。
- Git、`make`、Swift 编译器和 macOS SDK。最简单的准备方式是运行：

```bash
xcode-select --install
```

如果系统提示 Command Line Tools 已安装，可以继续下一步。

### 从源码构建

```bash
git clone https://github.com/BLACKIELF/codex-account-manager-next.git ~/Documents/CodexAccountManagerNext
cd ~/Documents/CodexAccountManagerNext
make build
```

构建成功后，App 位于：

```text
~/Documents/CodexAccountManagerNext/build/CodexAccountManagerNext.app
```

首次安装可以复制到当前用户的 Applications 文件夹：

```bash
mkdir -p "$HOME/Applications"
ditto build/CodexAccountManagerNext.app "$HOME/Applications/CodexAccountManagerNext.app"
open "$HOME/Applications/CodexAccountManagerNext.app"
```

如果已经安装过 Next，请先退出它并备份原来的 `CodexAccountManagerNext.app`，再替换。不要替换名称不同的旧版账号管理器。

## 第一次配置账号

1. 先确认 Codex 已经正常登录一个账号。
2. 打开 Codex Account Manager Next，进入账号管理区域。
3. 点击“添加账号”，优先选择“账号专属 Chrome”；也可以直接选择已有 Chrome 用户资料，再按官方浏览器流程登录。每个账号第一次完成 Google/OpenAI 登录后，会复用自己的浏览器会话，平时切号不会打开浏览器。
4. 为每个账号设置容易识别的名称，并确认账号卡能够显示官方额度。
5. 点击“监控”选择当前要观察的账号。
6. 没有运行中任务时，先对备用账号执行一次“切换并打开”，确认手动切换正常。

账号凭据保存在 Next 独立目录中。切换账号只改变 Codex 的当前登录，不会移动 Codex 项目和对话。

## 开启低额度自动换号

打开“自动化中心”，阅读确认提示后再启用“低额度自动换号”。只有以下条件同时满足时才会执行：

- 官方 5 小时窗口剩余 `<= 5%`，或 7 天窗口剩余 `< 10%`。
- 今日任务连接正常，快照不超过 45 秒，且没有运行中或等待输入的任务。
- Codex 已离开前台至少 2 分钟。
- 旧版 Codex Account Manager 没有运行。
- 备用账号身份验证一致，并且对应触发窗口的剩余额度均 `>= 30%`。
- 切换锁、凭据复核和冷却时间全部通过。

成功后冷却 30 分钟；失败后 1 小时再评估。Next 只会请求 Codex 优雅退出，退出失败时不会写入新凭据，也不会强制结束 Codex。

切换过程会保存私有恢复记录，等待本机额度读取结束，安全停止 Codex App 与共享 app-server，原子写入凭据，使用官方 app-server 冷验证目标身份和额度，再恢复共享运行时并重新打开 Codex。如果中途失败，Next 只会在当前凭据仍属于本次切换时恢复原账号，不会覆盖其他程序后来写入的新状态。

## 配置飞书通知

飞书通知使用群聊中的“自定义机器人”Webhook，不需要把 App Secret 写入项目。

### 配置逻辑

- `codex`、`wb` 等现有应用机器人负责对话或执行飞书能力，但它们的 App ID、App Secret 不是 Next 的通知入口。
- Next 只向目标群的“自定义机器人”Webhook 发送切换结果。这个 Webhook 属于该群，相当于一个只能向群里推送消息的长期凭据。
- 群里可以同时保留你、`codex`、`wb` 和通知机器人；它们互不替代。
- Webhook 由你直接粘贴到 Next 的“自动化中心”，随后只保存在 macOS 钥匙串。Agent 不需要看到、复制或记录它。
- 自动切换完成或失败后，Next 生成脱敏卡片并调用 Webhook。通知失败只记录告警，不会撤销已经完成的账号切换。
- 不再使用时，在 Next 中移除 Webhook，并在飞书群中删除对应自定义机器人。

### 让 Agent 帮你配置飞书

把下面整段话发送给能操作飞书客户端和本机 App 的 Agent：

> 请帮我把 Codex Account Manager Next 的账号切换结果推送到飞书。先确认目标群中只有我和我认可的应用机器人；现有 `codex` 或 `wb` 可以保留，但不要把它们的 App ID、App Secret 当成通知配置。进入该群的“群机器人”→“添加机器人”→“自定义机器人”，将机器人命名为“Codex 账号切换通知”。点击会生成 Webhook 的最终“添加”按钮前，向我确认一次。生成后不要把 Webhook 输出到对话、终端、日志、截图、剪贴板历史或项目文件；请引导我直接把它粘贴到 Codex Account Manager Next 的“自动化中心”→“飞书通知”，点击“安全保存”，再打开“飞书通知”开关。除非我单独确认，不要发送测试消息，也不要启用真实账号自动切换。最后只告诉我群成员、机器人名称、Next 是否显示“Webhook 已配置”和飞书通知开关状态，不要回显凭据。

如果 Agent 不能控制飞书客户端，它应该停在对应步骤，用简单语言告诉你下一次需要点击的位置，而不是要求你把 Webhook 发给它。

### 手动配置

1. 在飞书创建一个用于接收通知的群。飞书不允许纯单人群，群里至少需要另一位成员或一个现有应用机器人。
2. 打开群设置，进入“群机器人”，点击“添加机器人”。
3. 选择“自定义机器人”，填写名称和描述，然后点击“添加”。
4. 复制飞书生成的 Webhook。不要把它发送到 AI 对话、源代码、截图、日志或公开消息中。
5. 打开 Next 的“自动化中心”，在“飞书通知”中直接粘贴 Webhook，点击“安全保存”。
6. Webhook 保存成功后，打开“飞书通知”开关。
7. 只有在你愿意向群里发送真实消息时，才点击“发送测试”。

Webhook 只保存在 macOS 钥匙串。Next 不会把它回填到界面、写入设置文件或记录到日志。当前只接受：

```text
https://open.feishu.cn/open-apis/bot/v2/hook/...
https://open.larksuite.com/open-apis/bot/v2/hook/...
```

通知只包含脱敏账号标识、触发窗口、剩余额度、切换结果和时间。飞书发送失败不会改变账号切换结果。

## 日常使用

- 在菜单栏查看额度，点击账号卡的“监控”切换观察对象。
- 需要立即换号时，点击目标账号的“切换并打开”。
- 需要无人值守换号时，在“自动化中心”启用低额度自动换号。
- 在“自动化中心”查看最近的自动化事件和失败原因。
- 设置页面可以调整状态栏、全局快捷键、浅色/深色配色和更新检查。
- 主窗口还保留今日任务、Automation、Session、本机 Token/成本、趋势、项目、Skill、本机推理性能和 AI 领导力视图。

## 与旧版的关系

Next 使用独立命名空间：

| 项目 | Next 使用的位置 |
|---|---|
| Bundle ID | `com.blackielf.codex-account-manager-next` |
| 可执行文件 | `CodexAccountManagerNext` |
| 保存账号 | `~/.codex-account-manager-next/profiles/` |
| 应用数据 | `~/Library/Application Support/CodexAccountManagerNext/` |
| 缓存 | `~/Library/Caches/CodexAccountManagerNext/` |

开发、构建和安装 Next 不会覆盖旧版 App。两者都会操作 Codex 当前登录使用的 `~/.codex/auth.json`，因此不要同时用两个管理器切换账号。Next 会检测旧版进程并停止自动切换，但旧版不共享 Next 的切换锁，无法保证跨版本并发时完全没有竞态。

## 隐私、网络和费用

- 项目不会提供、创建或出售 Codex 账号，也不会增加 OpenAI 额度。
- 账号凭据不会显示在界面、诊断、日志或飞书消息中。
- Next 会通过本机 Codex CLI 和 `codex app-server` 获取官方身份、额度和任务状态。
- 更新检查会读取本仓库的公开 GitHub Release 信息，不会静默安装更新。
- 只有启用飞书通知后，脱敏的切换结果才会发送到你配置的飞书群。
- 本项目本身不收取费用；Codex、OpenAI、飞书或网络服务的费用与限制由各自服务决定。

详细边界见 [SECURITY.md](SECURITY.md)。

## 常见问题

### 看不到账号或官方额度

- 确认 Codex App 或 CLI 已安装并正常登录。
- 在账号卡中重新登录该账号，等待身份与额度验证完成。
- 如果本机 `codex app-server` 不可用，Next 会停止自动切换，不会使用猜测数据。

### 为什么又要求登录 Google/OpenAI

- 第一次添加账号、官方会话失效、修改密码或触发安全验证时，仍必须完成官方登录；Next 不读取或绕过密码、Cookie、MFA。
- 在账号卡的 Chrome 菜单中绑定正确的 Chrome 用户资料，或选择“自动匹配 / 账号专属”。账号专属会话会长期保留在该账号的独立目录中，减少以后重复选择 Google 邮箱。

### 额度已经很低，但没有自动切换

- 5 小时窗口需要剩余不高于 `5%`；7 天窗口正好 `10%` 不触发，必须严格低于 `10%`。
- 检查是否有运行中或等待输入的任务。
- 检查 Codex 是否仍在前台，或旧版账号管理器是否正在运行。
- 确认至少一个备用账号通过实时验证，并在对应窗口剩余 `30%` 或更多。
- 查看“自动化中心”的事件记录，确认是哪个安全条件阻止了切换。

### 飞书通知失败

- 确认使用的是群聊“自定义机器人”生成的完整 Webhook。
- 确认机器人仍在群中，并且 Webhook 域名属于上方允许列表。
- 重新保存 Webhook 后再手动点击“发送测试”。
- 不要把 Webhook 粘贴到终端命令、Issue 或聊天消息中排查。

### 如何更新

回到第一次安装时保留的源码目录：

```bash
git pull --ff-only
make build
```

退出已经安装的 Next，备份原 App，然后用新的 `build/CodexAccountManagerNext.app` 替换它。更新不会自动启用账号切换或飞书通知。

## 给编程 Agent 的检查命令

修改或更新项目后运行：

```bash
make build
codesign --verify --deep --strict build/CodexAccountManagerNext.app
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-automatic-account-switch
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-switch-safety
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-feishu-webhook
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-automation-audit
```

这些检查不会证明真实登录、真实账号切换或真实飞书发送已经成功。发布或交付前，仍应在得到明确授权后使用测试账号和测试群做端到端验证。

## 版本、来源和许可

- 正式版本：`0826v1`
- Bundle 版本：`8.26.1 (2)`
- 本次详细设计与验证：[docs/0826v1-IMPLEMENTATION.md](docs/0826v1-IMPLEMENTATION.md)
- 直接基线：Codex Account Manager 0818v1 的当前工作树
- 上游：基于 [codexU](https://github.com/shanggqm/codexU) 的 SwiftUI 项目
- 成熟方案研究：[docs/REFERENCE_IMPLEMENTATIONS.md](docs/REFERENCE_IMPLEMENTATIONS.md)
- 许可证：[MIT](LICENSE)
