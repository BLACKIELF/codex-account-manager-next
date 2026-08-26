import AppKit
import SwiftUI

struct CodexAccountManagerView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    let paletteCatalog: PaletteCatalog
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isEditingProfiles = false
    @State private var isAddingCustomTokenSource = false
    @State private var customSourceNameDraft = ""
    @State private var customSourceTokensDraft = ""
    @State private var isAgentBreakdownExpanded = false
    @State private var isAutomationCenterPresented = false

    static let defaultWidth: CGFloat = 1080
    static let minWidth: CGFloat = 960
    static let maxWidth: CGFloat = 1280
    static let defaultHeight: CGFloat = 740
    static let minHeight: CGFloat = 640
    static let windowCornerRadius: CGFloat = 28

    private var effectiveColorScheme: ColorScheme {
        settings.themeMode.preferredColorScheme ?? colorScheme
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            workspace
                .padding(22)
        }
        .background(
            FixedVisualPalette.windowScrim(
                effectiveColorScheme,
                reduceTransparency: reduceTransparency
            )
            .ignoresSafeArea()
        )
        .environment(
            \.visualTokens,
            paletteCatalog.resolve(
                id: settings.paletteID,
                appearance: effectiveColorScheme == .dark ? .dark : .light
            )
        )
        .preferredColorScheme(settings.themeMode.preferredColorScheme)
        .sheet(isPresented: $isAutomationCenterPresented) {
            AccountAutomationCenterView(store: store)
        }
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 16) {
            workspaceHeader

            HStack(alignment: .top, spacing: 14) {
                quotaOverview
                tokenTotalPanel
                    .frame(width: 286)
            }

            agentBreakdownPanel
            automationPanel

            profilesPanel
            safetyFooter

            if let message = store.accountManagerMessage {
                Label(message, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var workspaceHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("账号工作台")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("查看额度、保存快照，并切换当前 Codex 登录账号")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            Button {
                store.snapshotCurrentProfile()
            } label: {
                Label("保存快照", systemImage: "camera")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                store.refreshQuotaAndWarmUp()
            } label: {
                Label(store.isRefreshing ? "读取中…" : "刷新额度", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.isRefreshing)
        }
    }

    private var quotaOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.14))
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedAccountName)
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.snapshot.quotaReadSucceeded ? Color.green : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(store.snapshot.quotaReadSucceeded ? "官方额度已连接" : "等待官方额度")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                Spacer()

                Label(accountPlan, systemImage: accountPlanIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.14)))
            }

            HStack(spacing: 16) {
                QuotaRingGauge(
                    title: "7 天剩余",
                    window: store.snapshot.sevenDayQuota
                )
                Divider()
                    .frame(height: 108)
                VStack(spacing: 9) {
                    QuotaDetailTile(
                        title: "5 小时窗口",
                        icon: "timer",
                        window: store.snapshot.fiveHourQuota
                    )
                    QuotaDetailTile(
                        title: "7 天窗口",
                        icon: "calendar.badge.clock",
                        window: store.snapshot.sevenDayQuota
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 224, maxHeight: 224, alignment: .topLeading)
        .sectionBackground()
    }

    private var localAllAgentsTokens: Int64? {
        store.snapshot.local?.allAgentsLifetimeTokens ?? store.snapshot.local?.lifetimeTokens
    }

    private var combinedTokensTotal: Int64? {
        let official = officialAccountsTotal ?? 0
        let local = localAllAgentsTokens ?? 0
        guard official > 0 || local > 0 else { return nil }
        return official + local
    }

    private var combinedEquivalentCostUSD: Double? {
        guard let combinedTokensTotal,
              let localTokens = store.snapshot.local?.detailedUsage?.lifetime.tokens
        else { return nil }
        return estimatedSolProEquivalentCostUSD(
            officialTotalTokens: combinedTokensTotal,
            localTokens: localTokens
        )
    }

    private var tokenTotalPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("总消耗", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                Text("官方 + 本机").profileBadge()
            }

            Text(TokenFormatter.formatChineseTotal(combinedTokensTotal))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            HStack(alignment: .firstTextBaseline) {
                Text("所有账号 + 本机全 Agent")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let cost = combinedEquivalentCostUSD {
                    Text(String(format: "API 等效 ≈ $%.0f · ¥%.0f", cost, cost * 6.8))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let accountTotal = officialAccountsTotal {
                HStack(alignment: .firstTextBaseline) {
                    Text("账号 Token · 官方统计")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(TokenFormatter.formatChineseTotal(accountTotal) + " Token")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tint)
                }
                if let statsAsOf = officialAccountsStatsAsOf {
                    Text("统计至 " + statsAsOf.formatted(.dateTime.month().day()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("账号官方统计暂不可用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let localTotal = localAllAgentsTokens {
                HStack(alignment: .firstTextBaseline) {
                    Text("本机全 Agent · 本地记录")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(TokenFormatter.formatChineseTotal(localTotal) + " Token")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tint)
                }
                .help("本机记录的全部 Agent（Codex、Claude Code、ZCode、自定义来源等）全时段 token 总和，本地口径")
            }

        }
        .padding(18)
        .frame(minHeight: 224, maxHeight: 224, alignment: .topLeading)
        .sectionBackground()
        .accessibilityElement(children: .combine)
    }

    private var agentBreakdownPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    isAgentBreakdownExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("本机各 Agent 占比", systemImage: "chart.pie")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(TokenFormatter.formatChineseTotal(localAllAgentsTokens))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isAgentBreakdownExpanded ? 0 : -90))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isAgentBreakdownExpanded ? "收起各 Agent 占比" : "展开各 Agent 占比")

            if isAgentBreakdownExpanded {
                let shares = store.snapshot.local?.allAgentsShares ?? []
                let percentBase = max(Double(localAllAgentsTokens ?? 0), 1)
                if shares.isEmpty {
                    Text("暂无本机 Agent 记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(shares.prefix(10)) { share in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(share.name)
                                .font(.caption.weight(.medium))
                                .frame(minWidth: 110, alignment: .leading)
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.25))
                                    .frame(width: max(proxy.size.width * CGFloat(share.tokens) / CGFloat(percentBase), 2))
                            }
                            .frame(height: 6)
                            Text("\(Int((Double(share.tokens) / percentBase * 100).rounded()))%")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.tint)
                                .frame(width: 40, alignment: .trailing)
                            Text(TokenFormatter.formatChineseTotal(share.tokens))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .trailing)
                            if share.manual {
                                Button {
                                    removeCustomTokenSource(named: share.name)
                                } label: {
                                    Image(systemName: "xmark.circle")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .help("删除自定义来源")
                                .accessibilityLabel("删除自定义来源 \(share.name)")
                            } else {
                                Spacer().frame(width: 18)
                            }
                        }
                    }
                }
                Button {
                    customSourceNameDraft = ""
                    customSourceTokensDraft = ""
                    isAddingCustomTokenSource = true
                } label: {
                    Label("添加自定义来源", systemImage: "plus.circle")
                        .font(.caption2.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .help("手动录入其他 API 的累计用量，并入本机全 Agent 统计")
                .alert("添加自定义来源", isPresented: $isAddingCustomTokenSource) {
                    TextField("名称（如 美团）", text: $customSourceNameDraft)
                    TextField("累计 token（单位：万，如 5000）", text: $customSourceTokensDraft)
                    Button("添加") { addCustomTokenSource() }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("录入的用量会并入本机全 Agent 合计与占比")
                }
            }
        }
        .padding(18)
        .sectionBackground()
    }

    private func addCustomTokenSource() {
        let name = customSourceNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let tokens = customTokenCount(fromWanText: customSourceTokensDraft) else { return }
        var entries = CustomTokenSourceStore.load()
        entries.removeAll { $0.name == name }
        entries.append(CustomTokenSourceStore.Entry(name: name, tokens: tokens))
        CustomTokenSourceStore.save(entries)
        store.refresh(queueIfBusy: true)
    }

    private func removeCustomTokenSource(named name: String) {
        var entries = CustomTokenSourceStore.load()
        entries.removeAll { $0.name == name }
        CustomTokenSourceStore.save(entries)
        store.refresh(queueIfBusy: true)
    }

    private var officialAccountsTotal: Int64? {
        let totals = accountGroups.compactMap { group in
            group.compactMap { $0.officialProfile?.lifetimeTokens }.max()
        }
        return totals.isEmpty ? nil : totals.reduce(0, +)
    }

    private var officialAccountsStatsAsOf: Date? {
        accountGroups.compactMap { group in
            group.compactMap { $0.officialProfile?.statsAsOf }.max()
        }.min()
    }

    private var accountGroups: [[CodexProfile]] {
        CodexProfile.groupsByRecordedAccount(store.profiles)
    }

    private var presentedProfiles: [CodexProfile] {
        store.profiles.filter { profile in
            linkedManagedProfile(for: profile) == nil || profile.remark?.isEmpty == false
        }
    }

    private func isDuplicateAccount(_ profile: CodexProfile) -> Bool {
        (accountGroups.first { $0.contains(where: { $0.id == profile.id }) }?.count ?? 0) > 1
    }

    private func linkedManagedProfile(for profile: CodexProfile) -> CodexProfile? {
        guard profile.isSystemProfile else { return nil }
        return accountGroups.first { $0.contains(where: { $0.id == profile.id }) }?
            .first { !$0.isSystemProfile }
    }

    private func isCurrentCodexAccount(_ profile: CodexProfile) -> Bool {
        guard !profile.isSystemProfile else { return false }
        return accountGroups.first { $0.contains(where: { $0.id == profile.id }) }?
            .contains(where: { $0.isSystemProfile }) == true
    }

    private var profilesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label("账号与快照", systemImage: "person.2")
                        .font(.headline)
                    Text("额度、重置时间；暖号按已知重置时间执行一次，未知状态由手动刷新触发")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(presentedProfiles.count) 个账号")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button(isEditingProfiles ? "完成" : "编辑") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isEditingProfiles.toggle()
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityValue(isEditingProfiles ? "编辑模式已开启" : "编辑模式已关闭")
                Menu {
                    Button("账号专属 Chrome（推荐）") { store.addProfile() }
                    if !store.availableChromeProfiles.isEmpty { Divider() }
                    ForEach(store.availableChromeProfiles) { chromeProfile in
                        Button(chromeProfile.displayName) {
                            store.addProfile(using: chromeProfile)
                        }
                    }
                } label: {
                    Label(store.isLoggingIn ? "登录中…" : "添加账号", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoggingIn)
            }

            HStack(spacing: 12) {
                Text("智能暖号")
                    .font(.caption.weight(.semibold))
                Text("按各账号自己的 5 小时与 7 天窗口轮流执行")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Toggle("5 小时", isOn: Binding(
                    get: { store.warmUpSelection.fiveHour },
                    set: { store.setWarmUpFiveHourEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("打开后，各账号按自己的 5 小时重置时间串行执行；7 天剩余额度不高于 5% 时暂停到周窗口重置。")
                Toggle("7 天", isOn: Binding(
                    get: { store.warmUpSelection.sevenDay },
                    set: { store.setWarmUpSevenDayEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("打开后，各账号分别跟随自己的 7 天重置时间执行；失败不会自动重试。")
            }

            VStack(spacing: 9) {
                ForEach(Array(presentedProfiles.enumerated()), id: \.element.id) { index, profile in
                    let linkedProfile = linkedManagedProfile(for: profile)
                    ProfileRow(
                        profile: profile,
                        allProfiles: store.profiles,
                        isMonitoring: profile.id == store.selectedMonitorProfileID,
                        isLaunchProfile: profile.id == store.selectedLaunchProfileID,
                        isDuplicateAccount: isDuplicateAccount(profile),
                        isCurrentCodexAccount: isCurrentCodexAccount(profile),
                        linkedAccountName: linkedProfile.map { AccountDisplay.profileName($0) },
                        isEditing: isEditingProfiles,
                        isLoggingIn: store.isLoggingIn,
                        isLaunching: store.isLaunchingCodex,
                        canMoveUp: index > 0,
                        canMoveDown: index < presentedProfiles.count - 1,
                        remainingPercent: sevenDayRemaining(for: profile),
                        resetsAt: sevenDayReset(for: profile),
                        warmUpStatus: linkedProfile == nil ? store.warmUpStatus(for: profile) : nil,
                        resetCount: store.resetCount(for: profile),
                        resetCardExpiry: store.resetCardExpiry(for: profile),
                        chromeProfiles: store.availableChromeProfiles,
                        onMonitor: { store.selectMonitorProfile(profile.id) },
                        onRelogin: {
                            if linkedProfile != nil {
                                store.loginProfileIndependently(profile.id)
                            } else {
                                store.loginProfile(profile.id)
                            }
                        },
                        onLaunch: { store.launchCodex(with: profile.id) },
                        onRename: { store.setProfileRemark($0, for: profile.id) },
                        onSetChromeProfile: { store.setChromeProfile($0, for: profile.id) },
                        onMoveUp: {
                            let target = presentedProfiles[index - 1]
                            store.moveProfile(profile.id, relativeTo: target.id, before: true)
                        },
                        onMoveDown: {
                            let target = presentedProfiles[index + 1]
                            store.moveProfile(profile.id, relativeTo: target.id, before: false)
                        },
                        onDelete: { store.deleteProfile(profile.id) },
                        onAdjustResetCount: { store.adjustResetCount(for: profile, delta: $0) },
                        onSetResetCardExpiry: { store.setResetCardExpiry($0, for: profile) }
                    )
                }
            }

            HStack {
                Text("账号凭据独立保存；切换 Codex 时沿用当前电脑的项目与对话。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(store.isLoggingIn ? "取消登录" : "重新登录所选账号") {
                    if store.isLoggingIn {
                        store.cancelLogin()
                    } else {
                        store.loginSelectedMonitorProfile()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .sectionBackground()
    }

    private var automationPanel: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            .frame(width: 46, height: 46)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("安全自动换号")
                        .font(.headline)
                    Text("<10%")
                        .profileBadge()
                    if store.feishuNotificationsEnabled {
                        Label("飞书已启用", systemImage: "paperplane.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
                Text("5 小时或 7 天官方额度窗口低于 10%，实时确认无任务、Codex 离开前台且备用账号 ≥30% 后执行")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Label(
                store.automaticAccountSwitchEnabled ? "已开启" : "未开启",
                systemImage: store.automaticAccountSwitchEnabled ? "checkmark.shield.fill" : "shield"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(store.automaticAccountSwitchEnabled ? Color.green : Color.secondary)

            Button("自动化中心") {
                isAutomationCenterPresented = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .sectionBackground()
        .accessibilityElement(children: .contain)
    }

    private var safetyFooter: some View {
        HStack(spacing: 10) {
            Label("保存切换前快照", systemImage: "checkmark.circle.fill")
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Label("验证目标账号", systemImage: "checkmark.shield.fill")
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Label("切换本机登录", systemImage: "arrow.triangle.2.circlepath")
            Spacer()
            Text("失败时尝试并校验恢复")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .cardBackground(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }

    private var accountPlan: String {
        let plan = store.selectedMonitorProfile?.officialProfile?.planType
            ?? store.snapshot.account?.planType
        guard let plan, !plan.isEmpty else {
            return "官方服务"
        }
        return plan.uppercased()
    }

    private var accountPlanIcon: String {
        accountPlan == "PRO" ? "crown.fill" : "plus.circle.fill"
    }

    private var selectedAccountName: String {
        guard let profile = store.selectedMonitorProfile else { return "未选择账号" }
        return AccountDisplay.profileName(
            profile,
            fallbackRaw: store.snapshot.account?.email,
            allProfiles: store.profiles
        )
    }

    private func sevenDayRemaining(for profile: CodexProfile) -> Double? {
        guard linkedManagedProfile(for: profile) == nil else { return nil }
        if profile.id == store.selectedMonitorProfileID,
           let live = store.snapshot.sevenDayQuota?.remainingPercent {
            return live
        }
        return profile.lastSnapshot?.sevenDay.map { max(0, min(100, 100 - $0.usedPercent)) }
    }

    private func sevenDayReset(for profile: CodexProfile) -> Date? {
        guard linkedManagedProfile(for: profile) == nil else { return nil }
        if profile.id == store.selectedMonitorProfileID,
           let live = store.snapshot.sevenDayQuota?.resetsAt {
            return live
        }
        return profile.lastSnapshot?.sevenDay?.resetsAt
    }
}

private struct AccountAutomationCenterView: View {
    @ObservedObject var store: UsageStore
    @Environment(\.dismiss) private var dismiss
    @State private var webhookDraft = ""
    @State private var isConfirmingAutomaticSwitch = false
    @State private var isConfirmingWebhookRemoval = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.tint)
                }
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("自动化中心")
                        .font(.title2.weight(.bold))
                    Text("安全换号、飞书通知与本机审计")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    automaticSwitchGroup
                    feishuGroup
                    auditGroup
                }
                .padding(20)
            }
        }
        .frame(width: 620, height: 700)
        .confirmationDialog(
            "启用真实账号自动切换？",
            isPresented: $isConfirmingAutomaticSwitch,
            titleVisibility: .visible
        ) {
            Button("启用自动切换", role: .destructive) {
                store.setAutomaticAccountSwitchEnabled(true)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("触发后会替换真实 ~/.codex/auth.json，并在安全退出后重新打开 Codex。")
        }
        .alert("移除飞书 Webhook？", isPresented: $isConfirmingWebhookRemoval) {
            Button("移除", role: .destructive) {
                store.removeFeishuWebhook()
                webhookDraft = ""
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("钥匙串中的 Webhook 会被删除，飞书通知也会关闭。")
        }
    }

    private var automaticSwitchGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("低额度自动换号")
                            .font(.headline)
                        Text("默认关闭；所有安全条件同时满足后才执行")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("低额度自动换号", isOn: Binding(
                        get: { store.automaticAccountSwitchEnabled },
                        set: { enabled in
                            if enabled {
                                isConfirmingAutomaticSwitch = true
                            } else {
                                store.setAutomaticAccountSwitchEnabled(false)
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }

                Divider()

                HStack(spacing: 10) {
                    automationMetric(title: "触发", value: "< 10%", icon: "exclamationmark.triangle.fill")
                    automationMetric(title: "备用", value: "≥ 30%", icon: "battery.75percent")
                    automationMetric(title: "冷却", value: "30 分钟", icon: "clock.arrow.circlepath")
                }

                VStack(alignment: .leading, spacing: 8) {
                    safetyRule("官方 5 小时或 7 天窗口严格低于 10%")
                    safetyRule("实时任务状态已连接、数据新鲜，且没有运行或等待输入的任务")
                    safetyRule("Codex 已离开前台至少 2 分钟，旧版账号管理器未运行")
                    safetyRule("候选账号实时验证身份一致，对应额度窗口至少剩余 30%")
                    safetyRule("只做优雅退出；退出失败不写凭据，也不会强制结束 Codex")
                }

                Label(
                    "执行时会修改真实 ~/.codex/auth.json 并重新打开 Codex；失败会恢复原凭据。",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(4)
        } label: {
            Label("切换策略", systemImage: "arrow.triangle.2.circlepath")
                .font(.headline)
        }
    }

    private var feishuGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.feishuWebhookConfigured ? "Webhook 已配置" : "尚未配置 Webhook")
                            .font(.subheadline.weight(.semibold))
                        Text("地址只保存在 macOS 钥匙串；不会写入设置、日志或仓库")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("飞书通知", isOn: Binding(
                        get: { store.feishuNotificationsEnabled },
                        set: { store.setFeishuNotificationsEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!store.feishuWebhookConfigured)
                }

                SecureField("https://open.feishu.cn/open-apis/bot/v2/hook/…", text: $webhookDraft)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("飞书机器人 Webhook")

                HStack {
                    Button("安全保存") {
                        if store.saveFeishuWebhook(webhookDraft) {
                            webhookDraft = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(webhookDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("发送测试") {
                        store.sendFeishuTestNotification()
                    }
                    .disabled(!store.feishuWebhookConfigured)

                    Spacer()

                    if store.feishuWebhookConfigured {
                        Button("移除 Webhook", role: .destructive) {
                            isConfirmingWebhookRemoval = true
                        }
                    }
                }

                if let message = store.feishuNotificationMessage {
                    Label(message, systemImage: "paperplane")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.disabled)
                }
            }
            .padding(4)
        } label: {
            Label("飞书通知", systemImage: "paperplane.fill")
                .font(.headline)
        }
    }

    private var auditGroup: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                if store.automationEvents.isEmpty {
                    Label("尚无自动化事件", systemImage: "clock.badge.checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .center)
                } else {
                    ForEach(Array(store.automationEvents.prefix(12).enumerated()), id: \.element.id) { index, event in
                        if index > 0 { Divider().padding(.leading, 30) }
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: auditIcon(for: event.level))
                                .foregroundStyle(auditColor(for: event.level))
                                .frame(width: 20)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(event.title)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(event.occurredAt.formatted(.dateTime.month().day().hour().minute()))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Text(event.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 9)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(4)
        } label: {
            Label("最近事件", systemImage: "list.bullet.clipboard")
                .font(.headline)
        }
    }

    private func automationMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func safetyRule(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.shield")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func auditIcon(for level: AccountAutomationEvent.Level) -> String {
        switch level {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.octagon.fill"
        }
    }

    private func auditColor(for level: AccountAutomationEvent.Level) -> Color {
        switch level {
        case .info: return .accentColor
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }
}

struct CodexAccountMenuView: View {
    enum Screen {
        case home
        case accounts
        case settings
    }

    static let preferredSize = CGSize(width: 380, height: 610)

    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var updateStore: AppUpdateStore
    let paletteCatalog: PaletteCatalog
    let openFullWindow: () -> Void
    let openPaletteLibrary: () -> Void
    let quit: () -> Void

    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var screen: Screen
    @State private var isEditingAccounts = false
    @State private var profilePendingDeletion: CodexProfile?

    init(
        store: UsageStore,
        settings: AppSettings,
        updateStore: AppUpdateStore,
        paletteCatalog: PaletteCatalog,
        initialScreen: Screen = .home,
        openFullWindow: @escaping () -> Void,
        openPaletteLibrary: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.store = store
        self.settings = settings
        self.updateStore = updateStore
        self.paletteCatalog = paletteCatalog
        self.openFullWindow = openFullWindow
        self.openPaletteLibrary = openPaletteLibrary
        self.quit = quit
        _screen = State(initialValue: initialScreen)
    }

    private var colorScheme: ColorScheme {
        if let preferred = settings.themeMode.preferredColorScheme { return preferred }
        if settings.paletteID == PaletteCatalog.defaultPaletteID { return .dark }
        if settings.paletteID == "codexu.liquid-keycap" { return .light }
        return systemColorScheme
    }

    private var selectedProfile: CodexProfile? {
        store.selectedMonitorProfile
    }

    private var visibleProfiles: [CodexProfile] {
        store.profiles.filter { linkedManagedProfile(for: $0) == nil }
    }

    var body: some View {
        ZStack {
            menuBackdrop
            VStack(spacing: 0) {
                header
                Group {
                    switch screen {
                    case .home:
                        home
                    case .accounts:
                        accounts
                    case .settings:
                        settingsView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: Self.preferredSize.width, height: Self.preferredSize.height)
        .environment(\.colorScheme, colorScheme)
        .appVisualEnvironment(
            catalog: paletteCatalog,
            paletteID: settings.paletteID,
            appearance: PaletteAppearance(colorScheme)
        )
        .preferredColorScheme(colorScheme)
        .alert(item: $profilePendingDeletion) { profile in
            Alert(
                title: Text(text("删除“\(AccountDisplay.profileName(profile, allProfiles: store.profiles))”？", "Delete \(AccountDisplay.profileName(profile, allProfiles: store.profiles))?")),
                message: Text(text("账号及本机登录资料会移到废纸篓，不会删除你的 OpenAI 账号。", "Local login data will move to Trash. Your OpenAI account will not be deleted.")),
                primaryButton: .destructive(Text(text("删除账号", "Delete Account"))) {
                    store.deleteProfile(profile.id)
                },
                secondaryButton: .cancel(Text(text("取消", "Cancel")))
            )
        }
    }

    private var menuBackdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.08, green: 0.10, blue: 0.13).opacity(backdropOpacity + 0.16),
                       Color(red: 0.12, green: 0.13, blue: 0.16).opacity(backdropOpacity)]
                    : [Color.white.opacity(backdropOpacity + 0.22),
                       Color(red: 0.87, green: 0.91, blue: 0.93).opacity(backdropOpacity + 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.accentColor.opacity(0.11), .clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 250
            )
        }
        .ignoresSafeArea()
    }

    private var backdropOpacity: Double {
        if reduceTransparency { return colorScheme == .dark ? 0.82 : 0.90 }
        switch settings.accountMenuTransparency {
        case .clear: return 0.03
        case .standard: return 0.14
        case .frosted: return 0.30
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            if screen == .home {
                avatar(for: selectedProfile, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedProfile.map { AccountDisplay.profileName($0, allProfiles: store.profiles) } ?? text("未选择账号", "No Account"))
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.snapshot.quotaReadSucceeded ? Color.green : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(store.snapshot.quotaReadSucceeded
                             ? text("官方额度已连接 · \(planName)", "Official quota connected · \(planName)")
                             : text("等待官方额度", "Waiting for official quota"))
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    changeScreen(.home)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(AccountMenuIconButtonStyle())
                Text(screen == .accounts ? text("账号", "Accounts") : text("设置", "Settings"))
                    .font(.system(size: 17, weight: .semibold))
            }

            Spacer(minLength: 8)

            if screen == .home {
                Button {
                    store.refreshQuotaAndWarmUp()
                } label: {
                    Image(systemName: store.isRefreshing ? "hourglass" : "arrow.clockwise")
                }
                .buttonStyle(AccountMenuIconButtonStyle())
                .disabled(store.isRefreshing)
                .help(text("刷新额度", "Refresh quota"))

                Button {
                    changeScreen(.accounts)
                } label: {
                    Image(systemName: "person.2")
                }
                .buttonStyle(AccountMenuIconButtonStyle())
                .help(text("管理账号", "Manage accounts"))

                Button {
                    changeScreen(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(AccountMenuIconButtonStyle())
                .help(text("设置", "Settings"))
            } else if screen == .accounts {
                Button(isEditingAccounts ? text("完成", "Done") : text("编辑", "Edit")) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isEditingAccounts.toggle()
                    }
                }
                .buttonStyle(AccountGlassButtonStyle(tint: .clear, foreground: .primary, compact: true))

                Button {
                    store.addProfile()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(AccountMenuIconButtonStyle())
                .disabled(store.isLoggingIn)
                .help(text("添加账号", "Add account"))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5)
        }
    }

    private var home: some View {
        VStack(spacing: 12) {
            tokenHero
            HStack(spacing: 10) {
                statTile(
                    title: text("今日消耗", "Today"),
                    value: TokenFormatter.formatChineseTotal(
                        store.snapshot.local?.allAgentsTodayTokens
                            ?? store.snapshot.local?.todayTokens
                    ),
                    tint: .green
                )
                statTile(
                    title: text("会员有效期", "Membership"),
                    value: membershipSummary,
                    tint: membershipIsLow ? .red : .green
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(text("账号", "Accounts"))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(text("\(visibleProfiles.count) 个常用", "\(visibleProfiles.count) saved"))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                ScrollView(showsIndicators: visibleProfiles.count > 4) {
                    LazyVStack(spacing: 8) {
                        ForEach(visibleProfiles) { profile in
                            homeProfileRow(profile)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 2)
            .frame(maxHeight: .infinity)

            if let message = store.accountManagerMessage {
                Label(message, systemImage: "info.circle")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 9) {
                Button(text("管理账号", "Manage Accounts")) {
                    changeScreen(.accounts)
                }
                .buttonStyle(AccountGlassButtonStyle(tint: .clear, foreground: .primary))

                Button(text("打开完整窗口", "Open Full Window")) {
                    openFullWindow()
                }
                .buttonStyle(AccountGlassButtonStyle(tint: .blue, foreground: .white))
            }
        }
        .padding(14)
    }

    private var localAllAgentsTokens: Int64? {
        store.snapshot.local?.allAgentsLifetimeTokens ?? store.snapshot.local?.lifetimeTokens
    }

    private var combinedTokensTotal: Int64? {
        let official = officialAccountsTotal ?? 0
        let local = localAllAgentsTokens ?? 0
        guard official > 0 || local > 0 else { return nil }
        return official + local
    }

    private var combinedEquivalentCostUSD: Double? {
        guard let combinedTokensTotal,
              let localTokens = store.snapshot.local?.detailedUsage?.lifetime.tokens
        else { return nil }
        return estimatedSolProEquivalentCostUSD(
            officialTotalTokens: combinedTokensTotal,
            localTokens: localTokens
        )
    }

    private var tokenHero: some View {
        let sevenDayRemaining = store.snapshot.sevenDayQuota?.remainingPercent
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text("总 Token 消耗量", "Total token consumption"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(text("所有账号官方 + 本机全 Agent · 全时段", "All accounts + all local agents"))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let cost = combinedEquivalentCostUSD {
                    Text(String(format: "≈ $%.0f · ¥%.0f", cost, cost * 6.8))
                        .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(combinedTokensTotal.map(TokenFormatter.formatChineseTotal) ?? text("暂无记录", "No records"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(text("账号", "Accounts"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(officialAccountsTotal.map(TokenFormatter.formatChineseTotal) ?? text("暂不可用", "Unavailable"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(text("官方", "official"))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Text(text("本机全 Agent", "local agents"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(localAllAgentsTokens.map(TokenFormatter.formatChineseTotal) ?? text("暂无记录", "No records"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(text("本地", "local"))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Text(text("7 天剩余", "7-day left"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(resetSummary(store.snapshot.sevenDayQuota?.resetsAt))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(sevenDayRemaining.map { "\(Int($0.rounded()))%" } ?? "--")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            AccountSemanticQuotaTrack(percent: sevenDayRemaining, height: 6)
        }
        .padding(15)
        .accountMenuCard(highlighted: true)
    }

    private func statTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .accountMenuCard()
    }

    private func homeProfileRow(_ profile: CodexProfile) -> some View {
        let remaining = sevenDayRemaining(for: profile)
        return Button {
            if profile.id != store.selectedMonitorProfileID {
                store.selectMonitorProfile(profile.id)
            }
        } label: {
            HStack(spacing: 10) {
                avatar(for: profile, size: 30)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(AccountDisplay.profileName(profile, allProfiles: store.profiles))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        let resetCount = store.resetCount(for: profile)
                        if resetCount > 0 {
                            Label("\(resetCount)", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .help(text("本地记录：检测到该账号官方提前/随机重置 \(resetCount) 次", "Detected \(resetCount) early/random resets (local record)"))
                        }
                        if profile.id == store.selectedMonitorProfileID {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                        }
                    }
                    AccountSemanticQuotaTrack(percent: remaining, height: 6)
                }
                Text(remaining.map { "\(Int($0.rounded()))%" } ?? "--")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accountMenuCard(highlighted: profile.id == store.selectedMonitorProfileID)
        .accessibilityLabel(text("切换监控账号到 \(AccountDisplay.profileName(profile, allProfiles: store.profiles))", "Monitor \(AccountDisplay.profileName(profile, allProfiles: store.profiles))"))
    }

    private var accounts: some View {
        VStack(spacing: 10) {
            Text(text("切换监控只改变本面板数据；启动前会再次验证账号身份。", "Monitoring changes this panel only; identity is verified again before launch."))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .accountMenuCard()

            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 9) {
                    ForEach(visibleProfiles) { profile in
                        accountCard(profile)
                    }
                }
                .padding(.vertical, 1)
            }

            if let message = store.accountManagerMessage {
                Text(message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 9) {
                Button(store.isLoggingIn ? text("取消登录", "Cancel Login") : text("添加账号", "Add Account")) {
                    if store.isLoggingIn {
                        store.cancelLogin()
                    } else {
                        store.addProfile()
                    }
                }
                    .buttonStyle(AccountGlassButtonStyle(tint: .clear, foreground: .primary))
                Button(text("打开完整窗口", "Open Full Window")) { openFullWindow() }
                    .buttonStyle(AccountGlassButtonStyle(tint: .blue, foreground: .white))
            }
        }
        .padding(14)
    }

    private func accountCard(_ profile: CodexProfile) -> some View {
        let remaining = sevenDayRemaining(for: profile)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                avatar(for: profile, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(AccountDisplay.profileName(profile, allProfiles: store.profiles))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        let resetCount = store.resetCount(for: profile)
                        if resetCount > 0 {
                            Label("\(resetCount)", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .help(text("本地记录：检测到该账号官方提前/随机重置 \(resetCount) 次", "Detected \(resetCount) early/random resets (local record)"))
                        }
                        if profile.id == store.selectedMonitorProfileID {
                            Text(text("监控中", "Monitoring"))
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(.blue)
                        }
                    }
                    Text(profile.lastSnapshot.map {
                        text("更新于 ", "Updated ") + $0.fetchedAt.formatted(.dateTime.month().day().hour().minute())
                    } ?? text("等待账号验证", "Waiting for verification"))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(remaining.map { "\(Int($0.rounded()))%" } ?? "--")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            AccountSemanticQuotaTrack(percent: remaining, height: 7)

            HStack(spacing: 7) {
                if isEditingAccounts {
                    Button(text("重新登录", "Log In Again")) { store.loginProfile(profile.id) }
                        .buttonStyle(AccountGlassButtonStyle(tint: .blue, foreground: .white, compact: true))
                        .disabled(store.isLoggingIn || store.isLaunchingCodex)
                    Button {
                        moveProfile(profile, offset: -1)
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(AccountGlassButtonStyle(tint: .clear, foreground: .primary, compact: true))
                    .disabled(adjacentProfile(to: profile, offset: -1) == nil)
                    .help(text("上移账号", "Move account up"))
                    .accessibilityLabel(text("上移账号", "Move account up"))

                    Button {
                        moveProfile(profile, offset: 1)
                    } label: {
                        Image(systemName: "arrow.down")
                    }
                    .buttonStyle(AccountGlassButtonStyle(tint: .clear, foreground: .primary, compact: true))
                    .disabled(adjacentProfile(to: profile, offset: 1) == nil)
                    .help(text("下移账号", "Move account down"))
                    .accessibilityLabel(text("下移账号", "Move account down"))
                    if !profile.isSystemProfile {
                        Button(role: .destructive) {
                            profilePendingDeletion = profile
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(AccountGlassButtonStyle(tint: .red, foreground: .white, compact: true))
                        .disabled(store.isLaunchingCodex)
                        .accessibilityLabel(text("删除账号", "Delete account"))
                    }
                } else {
                    Button(profile.id == store.selectedMonitorProfileID ? text("已监控", "Monitoring") : text("监控", "Monitor")) {
                        store.selectMonitorProfile(profile.id)
                    }
                    .buttonStyle(AccountGlassButtonStyle(tint: .clear, foreground: .primary, compact: true))
                    .disabled(profile.id == store.selectedMonitorProfileID)

                    Button(text("切换并打开", "Switch & Open")) {
                        store.launchCodex(with: profile.id)
                    }
                    .buttonStyle(AccountGlassButtonStyle(tint: .blue, foreground: .white, compact: true))
                    .disabled(store.isLaunchingCodex)
                }
            }
        }
        .padding(11)
        .accountMenuCard(highlighted: profile.id == store.selectedMonitorProfileID)
    }

    private var settingsView: some View {
        VStack(spacing: 0) {
            SettingsPanelView(
                settings: settings,
                store: store,
                updateStore: updateStore,
                onOpenPaletteLibrary: openPaletteLibrary,
                compact: true,
                showsHeader: false
            )
            .frame(maxHeight: .infinity)

            HStack(spacing: 9) {
                Button(text("打开完整窗口", "Open Full Window")) { openFullWindow() }
                    .buttonStyle(AccountGlassButtonStyle(tint: .blue, foreground: .white))
                Button(text("退出", "Quit")) { quit() }
                    .buttonStyle(AccountGlassButtonStyle(tint: .clear, foreground: .primary))
            }
            .padding(14)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 0.5)
            }
        }
    }

    private func avatar(for profile: CodexProfile?, size: CGFloat) -> some View {
        let title = profile.map { AccountDisplay.profileName($0) } ?? ""
        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color.accentColor.opacity(0.13))
            if let first = title.first, !first.isASCII {
                Text(String(first)).font(.system(size: size * 0.52))
            } else {
                Image(systemName: profile?.isSystemProfile == true ? "house.fill" : "person.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var planName: String {
        (selectedProfile?.officialProfile?.planType ?? store.snapshot.account?.planType ?? "PLUS").uppercased()
    }

    private var officialAccountsTotal: Int64? {
        let totals = CodexProfile.groupsByRecordedAccount(store.profiles).compactMap { group in
            group.compactMap { $0.officialProfile?.lifetimeTokens }.max()
        }
        return totals.isEmpty ? nil : totals.reduce(0, +)
    }

    private var membershipDate: Date? {
        selectedProfile?.officialProfile?.subscriptionActiveUntil
    }

    private var membershipDays: Int? {
        guard let membershipDate else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: membershipDate)
        ).day
    }

    private var membershipSummary: String {
        guard let membershipDays else { return "--" }
        return membershipDays >= 0
            ? text("还有 \(membershipDays) 天", "\(membershipDays) days left")
            : text("已到期", "Expired")
    }

    private var membershipIsLow: Bool {
        (membershipDays ?? 99) <= 7
    }

    private func resetSummary(_ date: Date?) -> String {
        guard let date else { return text("官方未返回重置时间", "Reset time unavailable") }
        return text("\(date.formatted(.dateTime.month().day().hour().minute())) 重置", "Resets \(date.formatted(.dateTime.month().day().hour().minute()))")
    }

    private func sevenDayRemaining(for profile: CodexProfile) -> Double? {
        if profile.id == store.selectedMonitorProfileID,
           let remaining = store.snapshot.sevenDayQuota?.remainingPercent {
            return remaining
        }
        return profile.lastSnapshot?.sevenDay.map { max(0, min(100, 100 - $0.usedPercent)) }
    }

    private func linkedManagedProfile(for profile: CodexProfile) -> CodexProfile? {
        guard profile.isSystemProfile else { return nil }
        return CodexProfile.groupsByRecordedAccount(store.profiles)
            .first { $0.contains(where: { $0.id == profile.id }) }?
            .first { !$0.isSystemProfile }
    }

    private func adjacentProfile(to profile: CodexProfile, offset: Int) -> CodexProfile? {
        guard let index = visibleProfiles.firstIndex(where: { $0.id == profile.id }) else { return nil }
        let targetIndex = index + offset
        guard visibleProfiles.indices.contains(targetIndex) else { return nil }
        return visibleProfiles[targetIndex]
    }

    private func moveProfile(_ profile: CodexProfile, offset: Int) {
        guard let target = adjacentProfile(to: profile, offset: offset) else { return }
        store.moveProfile(profile.id, relativeTo: target.id, before: offset < 0)
    }

    private func changeScreen(_ target: Screen) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            screen = target
        }
    }

    private func text(_ zh: String, _ en: String) -> String {
        settings.language.text(zh, en)
    }
}

private struct AccountSemanticQuotaTrack: View {
    let percent: Double?
    var height: CGFloat = 8

    private var colors: [Color] {
        let colors = RemainingQuotaHealth.classify(percent).colors
        return [Color(nsColor: colors.start), Color(nsColor: colors.end)]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * CGFloat(max(0, min(100, percent ?? 0)) / 100))
            }
        }
        .frame(height: height)
        .accessibilityLabel("剩余额度")
        .accessibilityValue(percent.map { "\(Int($0.rounded()))%" } ?? "未知")
    }
}

private struct AccountMenuIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 29, height: 29)
            .background(.thinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.16), lineWidth: 0.75))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

private struct AccountGlassButtonStyle: ButtonStyle {
    let tint: Color
    let foreground: Color
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold))
            .lineLimit(1)
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(minWidth: compact ? 52 : 0, minHeight: compact ? 26 : 34)
            .padding(.horizontal, compact ? 8 : 10)
            .foregroundStyle(foreground)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
                    .fill(tint.opacity(tint == .clear ? 0 : 0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(tint == .clear ? 0.18 : 0.30), lineWidth: 0.75)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct AccountMenuCardModifier: ViewModifier {
    let highlighted: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(reduceTransparency ? 0.13 : (highlighted ? 0.10 : 0.065))
                        : Color.white.opacity(reduceTransparency ? 0.92 : (highlighted ? 0.62 : 0.46))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            highlighted ? Color.accentColor.opacity(0.45) : Color.primary.opacity(contrast == .increased ? 0.28 : 0.14),
                            lineWidth: highlighted ? 1 : 0.75
                        )
                )
        )
    }
}

private extension View {
    func accountMenuCard(highlighted: Bool = false) -> some View {
        modifier(AccountMenuCardModifier(highlighted: highlighted))
    }
}

struct ZYZHMark: View {
    @Environment(\.colorScheme) private var colorScheme
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width / 365, canvasSize.height / 264)
            let origin = CGPoint(
                x: (canvasSize.width - 365 * scale) / 2,
                y: (canvasSize.height - 264 * scale) / 2
            )
            let marks: [(CGRect, Color)] = [
                (CGRect(x: 7, y: 47, width: 213, height: 210), markColor(0)),
                (CGRect(x: 76, y: 25, width: 213, height: 210), markColor(1)),
                (CGRect(x: 145, y: 7, width: 213, height: 210), markColor(2))
            ]
            for (rect, color) in marks {
                let scaled = CGRect(
                    x: origin.x + rect.minX * scale,
                    y: origin.y + rect.minY * scale,
                    width: rect.width * scale,
                    height: rect.height * scale
                )
                context.stroke(
                    Path(roundedRect: scaled, cornerRadius: 58 * scale),
                    with: .color(color),
                    lineWidth: 14 * scale
                )
            }
        }
        .frame(width: size, height: size * 264 / 365)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("帧影帧画")
    }

    private func markColor(_ index: Int) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity([0.38, 0.64, 0.9][index])
        }
        return [
            Color(red: 20 / 255, green: 37 / 255, blue: 52 / 255),
            Color(red: 104 / 255, green: 121 / 255, blue: 133 / 255),
            Color(red: 168 / 255, green: 178 / 255, blue: 184 / 255)
        ][index]
    }
}

private struct QuotaRingGauge: View {
    let title: String
    let window: RateWindow?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var colors: [Color] {
        let colors = RemainingQuotaHealth.classify(window?.remainingPercent).colors
        return [Color(nsColor: colors.start), Color(nsColor: colors.end)]
    }

    private var progress: CGFloat {
        CGFloat(max(0, min(100, window?.remainingPercent ?? 0)) / 100)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(FixedVisualPalette.surfaceTrack, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: colors, center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: colors.last?.opacity(0.3) ?? .clear, radius: 7)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: progress)

            VStack(spacing: 2) {
                Text(window.map { "\(Int($0.remainingPercent.rounded()))%" } ?? "--")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 108, height: 108)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(window.map { "\(Int($0.remainingPercent.rounded()))%" } ?? "未知")
    }
}

private struct QuotaDetailTile: View {
    let title: String
    let icon: String
    let window: RateWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(window.map { "\(Int($0.remainingPercent.rounded()))%" } ?? "--")
                    .font(.caption.weight(.bold).monospacedDigit())
            }
            QuotaProgressTrack(percent: window?.remainingPercent)
            Text(resetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 11).fill(FixedVisualPalette.surfaceTrack.opacity(0.72)))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private var resetText: String {
        guard let reset = window?.resetsAt else { return "官方未返回重置时间" }
        let absolute = reset.formatted(.dateTime.month().day().hour().minute())
        let relative = RelativeDateTimeFormatter().localizedString(for: reset, relativeTo: Date())
        return "重置：\(absolute)（\(relative)）"
    }
}

private struct QuotaProgressTrack: View {
    let percent: Double?

    private var colors: [Color] {
        let colors = RemainingQuotaHealth.classify(percent).colors
        return [Color(nsColor: colors.start), Color(nsColor: colors.end)]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(FixedVisualPalette.surfaceTrack)
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * CGFloat(max(0, min(100, percent ?? 0)) / 100))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("剩余额度")
        .accessibilityValue(percent.map { "\(Int($0.rounded()))%" } ?? "未知")
    }
}

private struct ProfileRow: View {
    let profile: CodexProfile
    let allProfiles: [CodexProfile]
    let isMonitoring: Bool
    let isLaunchProfile: Bool
    let isDuplicateAccount: Bool
    let isCurrentCodexAccount: Bool
    let linkedAccountName: String?
    let isEditing: Bool
    let isLoggingIn: Bool
    let isLaunching: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let remainingPercent: Double?
    let resetsAt: Date?
    let warmUpStatus: String?
    let resetCount: Int
    var resetCardExpiry: Date? = nil
    let chromeProfiles: [ChromeProfileBinding]
    let onMonitor: () -> Void
    let onRelogin: () -> Void
    let onLaunch: () -> Void
    let onRename: (String) -> Void
    let onSetChromeProfile: (ChromeProfileBinding?) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let onAdjustResetCount: (Int) -> Void
    var onSetResetCardExpiry: ((Date?) -> Void)? = nil
    @State private var isEditingRemark = false
    @State private var isConfirmingDelete = false
    @State private var remarkDraft = ""

    private static let resetExpiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "dd/MM/yy HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: profile.isSystemProfile ? "house.fill" : "person.crop.circle")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 28)
                .foregroundStyle(isMonitoring ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(AccountDisplay.profileName(profile, allProfiles: allProfiles))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Label(planBadge.name, systemImage: planBadge.icon)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                        .accessibilityLabel("\(planBadge.name) 套餐")
                    if isMonitoring { Text("监控中").profileBadge() }
                    if isLaunchProfile { Text("启动账号").profileBadge() }
                    if linkedAccountName != nil {
                        Text("待独立登录")
                            .profileBadge()
                            .help("这张账号卡尚未保存独立登录；当前 Codex 登录不会被修改")
                    } else if isCurrentCodexAccount {
                        Text("当前 Codex").profileBadge()
                    } else if isDuplicateAccount {
                        Text("同一账号")
                            .profileBadge()
                            .help("这个 CODEX_HOME 与列表中的另一个入口登录了同一账号")
                    }
                    if isEditing {
                        Button {
                            remarkDraft = profile.remark ?? ""
                            isEditingRemark = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("修改备注")
                        .accessibilityLabel("修改账号备注")
                        if !profile.isSystemProfile {
                            Button {
                                isConfirmingDelete = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help("删除账号")
                            .accessibilityLabel("删除账号")
                            .disabled(isLaunching)
                            .alert("删除“\(AccountDisplay.profileName(profile, allProfiles: allProfiles))”？", isPresented: $isConfirmingDelete) {
                                Button("取消", role: .cancel) {}
                                Button("删除账号", role: .destructive) { onDelete() }
                            } message: {
                                Text("账号及其本机登录资料会移到废纸篓，不会删除你的 OpenAI 账号。")
                            }
                        }
                    }
                }
                Text(linkedAccountName.map { "本机 Codex 当前登录 \($0)；此卡尚未独立登录" } ?? profile.lastSnapshot.map {
                    "更新于 " + $0.fetchedAt.formatted(.dateTime.month().day().hour().minute())
                } ?? "等待账号验证")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if linkedAccountName == nil, let official = profile.officialProfile {
                    Text(officialAccountDetail(official))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let activeUntil = official.subscriptionActiveUntil {
                        Text(membershipDetail(activeUntil))
                            .font(.caption2)
                            .foregroundStyle(membershipRemainingDays(activeUntil) <= 7 ? Color.red : Color.secondary)
                            .lineLimit(1)
                    }
                }
                if let warmUpStatus {
                    Text(warmUpStatus)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 190, maxWidth: 260, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("7 天剩余")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise.circle")
                        Text("重置 \(resetCount) 次")
                        if let expiry = resetCardExpiry {
                            Text("· " + Self.resetExpiryFormatter.string(from: expiry))
                                .foregroundStyle(expiry <= Date() ? Color.red : Color.secondary.opacity(0.85))
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(FixedVisualPalette.surfaceTrack))
                    .help("本地记录：检测到该账号官方提前/随机重置 \(resetCount) 次（自动检测 + 手工校正）；有效期后为重置卡到期时间")
                    .accessibilityLabel("已被官方重置 \(resetCount) 次")
                    Text(remainingPercent.map { "\(Int($0.rounded()))%" } ?? "--")
                        .font(.caption.weight(.bold).monospacedDigit())
                }
                QuotaProgressTrack(percent: remainingPercent)
                Text(snapshotDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            if isEditing {
                if linkedAccountName == nil {
                    Button(isLoggingIn ? "登录中…" : "重新登录") { onRelogin() }
                        .buttonStyle(.bordered)
                        .disabled(isLoggingIn || isLaunching)
                }
                Menu {
                    Button("自动匹配 / 账号专属") { onSetChromeProfile(nil) }
                    if !chromeProfiles.isEmpty { Divider() }
                    ForEach(chromeProfiles) { chromeProfile in
                        Button(chromeProfile.displayName) { onSetChromeProfile(chromeProfile) }
                    }
                } label: {
                    Label(profile.chromeProfile?.displayName ?? "Chrome 专属", systemImage: "person.crop.circle")
                        .lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("首次登录或重新认证时使用；平时切号不会打开浏览器")
                VStack(spacing: 4) {
                    Text("重置 \(resetCount)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .help("本地记录的重置次数；加减号手动校正")
                    HStack(spacing: 4) {
                        Button {
                            onAdjustResetCount(-1)
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.bordered)
                        .help("重置次数减一")
                        .accessibilityLabel("重置次数减一")
                        .disabled(resetCount <= 0)
                        Button {
                            onAdjustResetCount(1)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .help("重置次数加一")
                        .accessibilityLabel("重置次数加一")
                    }
                    if let onSetResetCardExpiry {
                        DatePicker(
                            "有效期",
                            selection: Binding(
                                get: { resetCardExpiry ?? Date() },
                                set: { onSetResetCardExpiry($0) }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: 132)
                        .help("重置卡有效期；显示在重置次数后面")
                        if resetCardExpiry != nil {
                            Button {
                                onSetResetCardExpiry(nil)
                            } label: {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.bordered)
                            .help("清除重置卡有效期")
                            .accessibilityLabel("清除重置卡有效期")
                        }
                    }
                }
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.bordered)
                .help("上移账号")
                .accessibilityLabel("上移账号")
                .disabled(!canMoveUp || isLaunching)
                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.bordered)
                .help("下移账号")
                .accessibilityLabel("下移账号")
                .disabled(!canMoveDown || isLaunching)
            }
            if linkedAccountName != nil {
                Button(isLoggingIn ? "登录中…" : "登录") { onRelogin() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoggingIn || isLaunching)
                    .help("登录为独立账号，不修改当前 Codex 登录")
            } else {
                Button(isMonitoring ? "已监控" : "监控") { onMonitor() }
                    .buttonStyle(.bordered)
                    .disabled(isMonitoring)
            }
            Button("切换并打开") { onLaunch() }
                .buttonStyle(.borderedProminent)
                .disabled(isLaunching || linkedAccountName != nil)
        }
        .padding(13)
        .cardBackground(cornerRadius: 14, elevated: isMonitoring)
        .alert("修改账号备注", isPresented: $isEditingRemark) {
            TextField("例如：工作账号", text: $remarkDraft)
            Button("取消", role: .cancel) {}
            Button("保存") { onRename(remarkDraft) }
        } message: {
            Text("最多 40 个字符；留空会恢复脱敏账号名。")
        }
    }

    private var snapshotDetail: String {
        if linkedAccountName != nil { return "未保存独立额度快照" }
        let reset = resetsAt.map {
            "重置 " + $0.formatted(.dateTime.month().day().hour().minute())
        } ?? "重置时间未知"
        let fetched = profile.lastSnapshot.map {
            "快照 " + $0.fetchedAt.formatted(.dateTime.month().day().hour().minute())
        } ?? "尚未保存快照"
        return "\(reset) · \(fetched)"
    }

    private var planBadge: (name: String, icon: String) {
        if linkedAccountName != nil {
            return ("未登录", "person.crop.circle.badge.xmark")
        }
        return (profile.officialProfile?.planType ?? profile.lastSnapshot?.planType)?.lowercased() == "pro"
            ? ("PRO", "crown.fill")
            : ("PLUS", "plus.circle.fill")
    }

    private func officialAccountDetail(_ official: CodexOfficialProfileSnapshot) -> String {
        var parts: [String] = []
        if let total = official.lifetimeTokens {
            parts.append("官方累计 \(TokenFormatter.formatChineseTotal(total)) Token")
        }
        if let statsAsOf = official.statsAsOf {
            parts.append("统计至 " + statsAsOf.formatted(.dateTime.month().day()))
        }
        return parts.isEmpty ? "官方账号资料已连接" : parts.joined(separator: " · ")
    }

    private func membershipDetail(_ activeUntil: Date) -> String {
        let remainingDays = membershipRemainingDays(activeUntil)
        let date = activeUntil.formatted(.dateTime.month().day())
        return remainingDays >= 0
            ? "会员有效期还有 \(remainingDays) 天 · 至 \(date)"
            : "会员有效期已过 · \(date)"
    }

    private func membershipRemainingDays(_ activeUntil: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: activeUntil)
        ).day ?? 0
    }
}

enum AccountDisplay {
    static func profileName(
        _ profile: CodexProfile,
        fallbackRaw: String? = nil,
        allProfiles: [CodexProfile] = []
    ) -> String {
        let remark = profile.remark?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !remark.isEmpty { return remark }
        if profile.isSystemProfile, !allProfiles.isEmpty,
           let linkedRemark = linkedManagedRemark(for: profile, in: allProfiles) {
            return linkedRemark
        }
        if let displayName = profile.officialProfile?.displayName,
           !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayName
        }
        return masked(fallbackRaw ?? profile.name)
    }

    static func masked(_ raw: String) -> String {
        guard let at = raw.firstIndex(of: "@") else { return raw }
        let local = String(raw[..<at])
        guard local.count > 6 else { return local }
        return "\(local.prefix(3))•••\(local.suffix(3))"
    }

    private static func linkedManagedRemark(
        for profile: CodexProfile,
        in profiles: [CodexProfile]
    ) -> String? {
        guard profile.isSystemProfile else { return nil }
        return CodexProfile.groupsByRecordedAccount(profiles)
            .first { $0.contains(where: { $0.id == profile.id }) }?
            .first { !$0.isSystemProfile }?
            .remark?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension View {
    func profileBadge() -> some View {
        self
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(FixedVisualPalette.surfaceTrack))
    }
}
