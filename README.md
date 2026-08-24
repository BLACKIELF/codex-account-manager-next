# Codex Account Manager Next 0824v1

**中文** | [English](README.en.md)

本地优先的 macOS Codex 多账号、额度与任务控制台。Next 保留原版账号管理、菜单栏、额度、任务、Token/成本、本机推理性能、AI 领导力、配色、更新和 Windows 源码，并新增严格低额度自动切换与飞书通知。

> 非 OpenAI 官方项目。自动切换会替换当前 `~/.codex/auth.json` 并重启 Codex；两项自动化默认关闭，必须由用户主动启用。

## 低于 10% 自动切换

只有以下条件同时成立才会切换：

- 官方 5 小时或 7 天窗口剩余额度严格 `< 10%`；正好 `10%` 不触发。
- 今日任务长连接在线、快照不超过 45 秒，且没有运行中或等待输入的实时任务。
- Codex 已离开前台至少 2 分钟，旧版 Account Manager 未运行。
- 候选账号通过对应 `CODEX_HOME` 实时身份与额度校验，并在所有触发窗口均 `>= 30%`。
- 切换锁、源凭据二次校验和冷却时间均通过；失败后 1 小时再评估，成功后冷却 30 分钟。

切换复用同一条安全路径：同时绑定邮箱与稳定 `chatgpt_account_id`、获取跨进程文件锁、优雅退出 Codex、写入 `0600` 崩溃恢复记录、原子写入凭据、校验身份并重新打开。失败时只在当前凭据仍属于本次事务时恢复原凭据；若外部程序已更新凭据则保留最新状态并报错。不会为切换账号强杀 Codex。

## 飞书通知

- Webhook 仅保存在 macOS Keychain，不回填到界面、不写入项目状态或日志。
- 只接受 `https://open.feishu.cn/open-apis/bot/v2/hook/...` 与 `https://open.larksuite.com/open-apis/bot/v2/hook/...`，禁止重定向。
- 通知仅包含脱敏账号标识、触发窗口、剩余额度、结果与时间；切换失败也有独立结果卡片。
- 飞书失败不改变账号切换结果；“发送测试通知”只在用户明确点击时执行。

## 保留的现有能力

- 独立账号卡、保存/重登/排序/备注/删除，以及手动“切换并打开”。
- 官方 Codex app-server 身份、5 小时/7 天/月额度、重置次数与到期信息。
- 菜单栏额度环、主窗口、状态栏密度、全局快捷键、浅色/深色配色与可访问性基础。
- 今日任务、Automation、Session 打开，以及 Codex 本机 Token、成本、趋势、项目和 Skill 统计。
- 本机推理性能与 AI 领导力视图；CC Switch 数据库保持只读。
- 智能暖号改为显式手动刷新后的一次性计划，不在启动、唤醒或失败后自动重试。
- 原 macOS 发布脚本和 Windows Tauri 工作区均保留。

## 与原版隔离

- Bundle ID：`com.blackielf.codex-account-manager-next`
- 可执行文件：`CodexAccountManagerNext`
- 保存账号：`~/.codex-account-manager-next/profiles/`
- 应用数据：`~/Library/Application Support/CodexAccountManagerNext/`
- 缓存：`~/Library/Caches/CodexAccountManagerNext/`
- 全局快捷键默认关闭，避免与旧版抢占。

开发副本不会覆盖或启动原 App。真实手动/自动切换按产品定义会修改共享的 Codex 当前登录，因此不要与旧版管理器并发执行。Next 会重复检测旧版进程、在写入前比较当前凭据，并用独立锁串行化 Next 自身的切换；旧版不共享该锁，所以这些措施只能降低风险，不能保证跨版本并发时零竞态。

## 构建与纯本地验证

要求 macOS 13+、Codex CLI 与 Xcode Command Line Tools。构建不会安装或启动 App：

```bash
make build
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-automatic-account-switch
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-switch-safety
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-feishu-webhook
build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-automation-audit
```

本版本构建产物名为 `CodexAccountManagerNext-8.24.1-mac-arm64.dmg`。`make run`、`make probe`、真实账号切换和真实飞书发送都会访问本机或外部状态，应仅在可信环境显式执行。

## 版本与来源

- 正式版本：`0824v1`
- Bundle 版本：`8.24.1 (1)`
- 直接基线：Codex Account Manager 0818v1 的当前工作树
- 上游：基于 [codexU](https://github.com/shanggqm/codexU) 的 SwiftUI 项目
- 成熟方案研究：[docs/REFERENCE_IMPLEMENTATIONS.md](docs/REFERENCE_IMPLEMENTATIONS.md)
- 许可证：[MIT](LICENSE)
