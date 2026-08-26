# Codex Account Manager Next 0826v1

本次版本在不改写既有账号安全事务的前提下，收敛自动切换、暖号、统计和账号界面。正式版本为 `0826v1`，Bundle 版本为 `8.26.1 (2)`。

## 与 0824v1 的区别

| 模块 | 0824v1 | 0826v1 |
|---|---|---|
| 5 小时自动切换 | 剩余 `< 10%` | 剩余 `<= 5%` |
| 7 天自动切换 | 剩余 `< 10%` | 保持剩余 `< 10%` |
| 自动切换账号范围 | 所有已保存账号 | 每个账号可单独退出；源和目标都会再次校验范围 |
| 退出自动切换后的暖号 | 无独立规则 | 保留 7 天与官方随机重置暖号 |
| 暖号节流 | 窗口未知时可能短间隔再次执行 | 成功后按 5 小时或 7 天分别节流；失败不自动重试 |
| 总消耗 | 可能随账号或数据源切换回落 | 官方累计和本机累计分别保存高水位，只增不减 |
| Pro 展示 | 只显示 Pro | 用户可选择未指定、`5x`、`20x` |
| 当前账号按钮 | 可出现重复切换入口 | 明确显示“当前账号”并禁用 |
| 界面 | 控制密集、设置页接近上游 | 账号卡三段式信息层级，设置页使用 Next 标识和原生菜单 |

## 关键思路

### 1. 安全路径只复用，不重写

账号卡、“切换并打开”、自动切换和命令行验收最终都进入 `UsageStore.launchCodex(with:)`，继续使用既有的身份绑定、跨进程锁、Codex 优雅退出、恢复日志、原子凭据写入、目标身份校验、共享运行时恢复和受所有权约束的回滚。0826v1 只在进入事务前增加账号范围与阈值判断，没有复制或削弱安全逻辑。

### 2. 阈值按窗口分别表达

5 小时和 7 天窗口不再共用一个模糊阈值：5 小时剩余不高于 5% 时触发，7 天仍要求严格低于 10%。候选账号必须在所有触发窗口均保持至少 30%，缺少身份、额度、任务或进程证据时保持 fail-closed。

### 3. 自动切换范围与暖号解耦

“参与自动切换”只决定账号能否成为自动切换的源或目标。关闭后仍保留低频 7 天暖号；若检测到官方随机重置，也允许对应窗口执行一次暖号。这样可以保留账号活跃性，同时避免消耗用户不想用于自动切换的额度。

### 4. 暖号以窗口为时钟

成功暖号后，5 小时窗口至少等待 5 小时，7 天窗口至少等待 7 天。官方明确返回下一次重置时间时，以该账号自己的窗口为准。失败不会自动重试，避免后台重复消耗最小请求。

### 5. 累计统计使用高水位

官方账号累计与本机全 Agent 累计分别写入 Next 独立的 `UserDefaults` 键。界面展示 `max(历史值, 当前观测值)`，因此账号切换、短暂读取失败或数据源变化不会让累计数字倒退；正常新增使用量仍会继续增长。

### 6. Pro 倍率只是一项显示偏好

本地账号记录新增可选 `proTierMultiplier`，只接受 `5`、`20` 或空值，并在同一真实账号的重复配置间同步。该值不改变官方额度、候选排序或自动切换判断。

### 7. 文档截图从生产视图直接生成

`--render-documentation-settings` 直接渲染生产 `CodexAccountMenuView` 的设置页，使用独立临时偏好且不启动 `UsageStore.start()`。截图不显示账号列表，因此不会包含邮箱、账号 ID、Token、Webhook 或本机路径，也不需要上传真实画面进行二次打码。

## 验证

发布前执行：

```bash
make memory-risk-check
make BUILD_DIR=build-auth-refactor build
build-auth-refactor/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-profile-store
build-auth-refactor/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-automatic-account-switch
build-auth-refactor/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-account-switch-safety
build-auth-refactor/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-app-server-pipe
build-auth-refactor/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext --self-test-feishu-webhook
codesign --verify --deep --strict build-auth-refactor/CodexAccountManagerNext.app
git diff --check
```

本轮没有发送真实飞书通知，没有把账号凭据、原始界面截图或构建目录提交到仓库。纯自测不能代替不同机器上的真实登录和长期无人值守运行。
