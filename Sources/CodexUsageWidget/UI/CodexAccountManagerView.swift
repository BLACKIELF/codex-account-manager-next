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
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 16) {
            workspaceHeader

            HStack(alignment: .top, spacing: 14) {
                quotaOverview
                tokenTotalPanel
                    .frame(width: 286)
            }

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
                store.refresh(queueIfBusy: true)
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

    private var tokenTotalPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("总消耗", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                Text("官方统计").profileBadge()
            }

            Text(TokenFormatter.formatChineseTotal(officialAccountsTotal))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            HStack(alignment: .firstTextBaseline) {
                Text("账号 Token")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let cost = officialEquivalentCostUSD {
                    Text(String(format: "API 等效 ≈ $%.0f · ¥%.0f", cost, cost * 6.8))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let accountTotal = officialAccountsTotal {
                Text(accountTotal.formatted(.number.grouping(.automatic)) + " tokens")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
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

            if let localTotal = store.snapshot.local?.lifetimeTokens {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text("本机历史累计")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(TokenFormatter.formatChineseTotal(localTotal) + " Token")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.tint)
                }
            }

        }
        .padding(18)
        .frame(minHeight: 224, maxHeight: 224, alignment: .topLeading)
        .sectionBackground()
        .accessibilityElement(children: .combine)
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

    private var officialEquivalentCostUSD: Double? {
        guard let officialAccountsTotal,
              let localTokens = store.snapshot.local?.detailedUsage?.lifetime.tokens
        else { return nil }
        return estimatedSolProEquivalentCostUSD(
            officialTotalTokens: officialAccountsTotal,
            localTokens: localTokens
        )
    }

    private var profilesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label("账号与快照", systemImage: "person.2")
                        .font(.headline)
                    Text("额度、重置时间与智能暖号状态")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(presentedProfiles.count) 个账号")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Toggle(isOn: Binding(
                    get: { store.automaticWarmUpEnabled },
                    set: { store.setAutomaticWarmUpEnabled($0) }
                )) {
                    Label("智能暖号", systemImage: "bolt.fill")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("按每个账号的 5 小时窗口自动发送一次“你好”；低额度与过期会员会暂停")
                Button(isEditingProfiles ? "完成" : "编辑") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isEditingProfiles.toggle()
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityValue(isEditingProfiles ? "编辑模式已开启" : "编辑模式已关闭")
                Button {
                    store.addProfile()
                } label: {
                    Label(store.isLoggingIn ? "登录中…" : "添加账号", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoggingIn)
            }

            VStack(spacing: 9) {
                ForEach(Array(presentedProfiles.enumerated()), id: \.element.id) { index, profile in
                    let linkedProfile = linkedManagedProfile(for: profile)
                    ProfileRow(
                        profile: profile,
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
                        onMoveUp: {
                            let target = presentedProfiles[index - 1]
                            store.moveProfile(profile.id, relativeTo: target.id, before: true)
                        },
                        onMoveDown: {
                            let target = presentedProfiles[index + 1]
                            store.moveProfile(profile.id, relativeTo: target.id, before: false)
                        },
                        onDelete: { store.deleteProfile(profile.id) }
                    )
                }
            }

            HStack {
                Text("账号凭据独立保存；切换 Codex 时沿用当前电脑的项目与对话。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(store.isLoggingIn ? "登录中…" : "重新登录所选账号") {
                    store.loginSelectedMonitorProfile()
                }
                .buttonStyle(.bordered)
                .disabled(store.isLoggingIn)
            }
        }
        .padding(18)
        .sectionBackground()
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
            Text("失败自动回滚")
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
        return AccountDisplay.profileName(profile, fallbackRaw: store.snapshot.account?.email)
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
                title: Text(text("删除“\(AccountDisplay.profileName(profile))”？", "Delete \(AccountDisplay.profileName(profile))?")),
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
                    Text(selectedProfile.map { AccountDisplay.profileName($0) } ?? text("未选择账号", "No Account"))
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
                    store.refresh(queueIfBusy: true)
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
            quotaHero
            HStack(spacing: 10) {
                statTile(
                    title: text("官方累计", "Official Total"),
                    value: officialAccountsTotal.map(TokenFormatter.formatChineseTotal) ?? "--",
                    tint: .blue
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

    private var quotaHero: some View {
        let remaining = store.snapshot.sevenDayQuota?.remainingPercent
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text("7 天剩余额度", "7-day quota remaining"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(resetSummary(store.snapshot.sevenDayQuota?.resetsAt))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(remaining.map { "\(Int($0.rounded()))%" } ?? "--")
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            AccountSemanticQuotaTrack(percent: remaining, height: 11)
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
                        Text(AccountDisplay.profileName(profile))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
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
        .accessibilityLabel(text("切换监控账号到 \(AccountDisplay.profileName(profile))", "Monitor \(AccountDisplay.profileName(profile))"))
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
                Button(text("添加账号", "Add Account")) { store.addProfile() }
                    .buttonStyle(AccountGlassButtonStyle(tint: .clear, foreground: .primary))
                    .disabled(store.isLoggingIn)
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
                        Text(AccountDisplay.profileName(profile))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
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
    let onMonitor: () -> Void
    let onRelogin: () -> Void
    let onLaunch: () -> Void
    let onRename: (String) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    @State private var isEditingRemark = false
    @State private var isConfirmingDelete = false
    @State private var remarkDraft = ""

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: profile.isSystemProfile ? "house.fill" : "person.crop.circle")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 28)
                .foregroundStyle(isMonitoring ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(AccountDisplay.profileName(profile))
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
                            .alert("删除“\(AccountDisplay.profileName(profile))”？", isPresented: $isConfirmingDelete) {
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
    static func profileName(_ profile: CodexProfile, fallbackRaw: String? = nil) -> String {
        let remark = profile.remark?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return remark.isEmpty ? masked(fallbackRaw ?? profile.name) : remark
    }

    static func masked(_ raw: String) -> String {
        guard let at = raw.firstIndex(of: "@") else { return raw }
        let local = String(raw[..<at])
        guard local.count > 6 else { return local }
        return "\(local.prefix(3))•••\(local.suffix(3))"
    }

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
