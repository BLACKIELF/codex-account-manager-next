# TAURI P1/P2 Bugfix Review (Updated)

- Report date: 2026-07-26
- Scope: Windows Tauri settings fix set (confirmed actionable items only).
- Files touched:
  - `windows/apps/codexu-tauri/web/src/hooks/useSettings.ts`
  - `windows/apps/codexu-tauri/src-tauri/src/commands/settings.rs`
  - `windows/apps/codexu-tauri/web/src/windows/Settings.tsx`

## 已修复问题

### P1-2 | `set_settings` IPC 参数名不匹配
- 根因：前端调用 `invoke('set_settings', patch)` 与后端参数名 `req` 不一致。
- 受影响行为：设置更新不能正确入参。
- 修复：改为 `invoke('set_settings', { req: patch })`。

### P1-3 | `open_settings_window` 异步路径使用 `blocking_read()`
- 根因：在 async 命令中同步读取 lock。
- 受影响行为：可能阻塞 runtime。
- 修复：改用 `read().await` 读取 theme 再应用。

### P2-4 | Settings 页面“保存成功”误报
- 根因：更新失败也会触发 `flashSaved()`。
- 受影响行为：失败写入仍提示成功。
- 修复：通过 `runUpdate` 保证仅成功路径才显示成功提示，并在成功后应用主题。

## 其他核查

- `before*Command` 路径在实际 `cargo tauri build --no-bundle` 调用链下为 `src-tauri/scripts/frontend-hook.mjs ...`，属于 false-positive ruled out，本轮未改动配置。

## 验证

1. `cargo test --workspace`
   - 路径：`windows`
   - 退出码：`0`
   - 结果：通过

2. `npm run build`
   - 路径：`windows/apps/codexu-tauri/web`
   - 退出码：`0`
   - 结果：通过

3. `cargo tauri build --no-bundle`
   - 路径：`windows/apps/codexu-tauri/src-tauri`
   - 退出码：`0`
   - 结果：beforeBuild hook 按真实路径执行通过，构建成功

4. `git diff --check`
   - 路径：repo root
   - 退出码：`0`
   - 结果：通过

## 限制

- 未引入专用 Tauri IPC 集成 harness。
- 未改动版本号、macOS 实现、README、锁文件或生成产物。