# Codex Account Manager 0818v1

**中文** | [English](README.en.md)

一个本地优先的 macOS Codex 多账号管理与额度监控工具，基于 [codexU v1.3.0](https://github.com/shanggqm/codexU) 的 SwiftUI 外壳改造。

## 主要能力

- 每个保存账号使用独立 `CODEX_HOME`；当前 Codex 登录沿用 `~/.codex`，其他账号保存在 `~/.codexu/p/<短ID>`。
- 通过官方 `codex app-server` 读取账号身份、5 小时/7 天剩余额度与重置时间，并阻止身份不匹配的额度快照串号。
- 菜单栏面板始终跟随当前默认 Codex 登录；账号顺序、备注、重新登录和独立登录均可在本机管理。
- “切换并打开”会先保存当前登录，再通过官方 `codex logout` 切换到已验证的本地凭据，并激活现有 Codex，不主动结束正在运行的 Codex 进程。
- 菜单栏圆环、主界面和账号列表统一表达“剩余健康度”：`55–100%` 蓝色、`25–54%` 黄色、`0–24%` 红色。
- 内置液态键帽浅色/深色配色和可调玻璃透明度。
- CC Switch 数据库只读；其本机历史 Token 是全局估算，不作为官方账单或账号归属依据。

## 切换与安全边界

切换账号只在本机读写 `auth.json`：目标身份必须与账号卡已保存身份匹配，写入使用原子替换和 `0600` 权限；失败时恢复切换前文件。凭据内容不会显示、写入日志或上传 GitHub。

首次切到其他账号时，应用会把当前默认登录保存在独立目录，再更新 `~/.codex/auth.json`。默认 `CODEX_HOME` 不变，因此本机项目与对话索引仍由当前 Codex 数据目录维护。Codex 官方注销行为或服务端令牌策略发生变化时，可能仍需重新登录。

“智能暖号”会在用户开启后通过官方 Codex 发送最小请求，会消耗账号额度；默认逻辑会避开额度过低、订阅失效和重复执行窗口。

更多数据与网络边界见 [SECURITY.md](SECURITY.md)。

## 数据口径

- **官方额度**：来自对应 `CODEX_HOME` 启动的 Codex app-server。
- **当前账号**：以默认 `~/.codex/auth.json` 验证到的身份为准；菜单栏会自动匹配同一账号卡。
- **本机历史 Token**：来自本机 Codex 数据及可选的 `~/.cc-switch/cc-switch.db` 只读统计，不等同官方账单。

## 构建与验证

要求 macOS 13+、Codex CLI 和 Xcode Command Line Tools。

```bash
make build
make test-profile-store
make test-cc-switch
build/CodexAccountManager.app/Contents/MacOS/CodexAccountManager --self-test-status-item
```

运行本地构建：

```bash
open -n build/CodexAccountManager.app
```

以上命令不会自动覆盖 `/Applications` 中的应用。`make probe` 会读取当前本机数据并向终端输出诊断 JSON，请只在可信环境运行。

## 版本与来源

- 正式名称：`0818v1`
- Bundle 版本：`8.18.1 (1)`
- 来源：codexU v1.3.0
- 许可证：MIT，见 [LICENSE](LICENSE)

本项目是非官方工具，与 OpenAI 无隶属关系。
