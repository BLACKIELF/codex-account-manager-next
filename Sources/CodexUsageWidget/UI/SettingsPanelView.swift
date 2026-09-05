import Cocoa
import SwiftUI

let titlebarControlHeight: CGFloat = 18
let settingsAccessoryColumnWidth: CGFloat = 184
let settingsControlCornerRadius: CGFloat = 8
let settingsSegmentHeight: CGFloat = 30
let settingsControlVisualHeight: CGFloat = settingsSegmentHeight + 6
let settingsSectionTitleFontSize: CGFloat = 12.5
let settingsSectionDetailFontSize: CGFloat = 10
let settingsRowTitleFontSize: CGFloat = 11.5
let settingsRowDetailFontSize: CGFloat = 9.5
let settingsControlFontSize: CGFloat = 11
private let settingsContentTopInset: CGFloat = 12
private let settingsSwitchWidth: CGFloat = 56
private let settingsShortcutControlSpacing: CGFloat = 8
private let settingsShortcutRecorderWidth: CGFloat = 108
private let settingsShortcutActionWidth: CGFloat =
    settingsAccessoryColumnWidth
    - settingsShortcutRecorderWidth
    - settingsShortcutControlSpacing

struct HeaderActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.visualTokens) private var visualTokens
    @State private var isHovering = false

    let systemName: String
    var isActive = false
    var hoverTint: Color?
    let help: String
    let accessibilityLabel: String
    var accessibilityValue: String?
    let action: () -> Void

    private var foregroundColor: Color {
        if isActive {
            return visualTokens.selection.foreground.color
        }
        if isHovering, let hoverTint {
            return hoverTint
        }
        return Color.secondary
    }

    private var fillColor: Color {
        if isActive {
            return visualTokens.selection.fill.color
        }
        if isHovering {
            return FixedVisualPalette.controlSelectedFill(colorScheme)
        }
        return Color.clear
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: titlebarControlHeight, height: titlebarControlHeight)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(fillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isActive ? visualTokens.selection.stroke.color : Color.clear,
                            lineWidth: 0.8
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "")
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct TitlebarToolbarView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    let onOpenSettings: () -> Void

    private var language: WidgetLanguage { settings.language }
    private var themeMode: WidgetThemeMode { settings.themeMode }
    private var effectiveColorScheme: ColorScheme {
        themeMode.preferredColorScheme ?? colorScheme
    }

    var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            ZYZHMark(size: 27)
                .frame(width: 34, height: titlebarControlHeight)
                .help("帧影帧画")

            HStack(spacing: 2) {
                HeaderActionButton(
                    systemName: "gearshape",
                    help: language.text("设置", "Settings"),
                    accessibilityLabel: language.text("设置", "Settings")
                ) {
                    onOpenSettings()
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(FixedVisualPalette.controlFill(effectiveColorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(FixedVisualPalette.controlStroke(effectiveColorScheme), lineWidth: 0.8)
                    )
            )
        }
        .padding(.top, 12)
        .padding(.bottom, 2)
        .padding(.trailing, 18)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .topTrailing)
        .appVisualEnvironment(
            catalog: settings.paletteCatalog,
            paletteID: settings.paletteID,
            appearance: PaletteAppearance(effectiveColorScheme)
        )
        .environment(\.colorScheme, effectiveColorScheme)
        .preferredColorScheme(themeMode.preferredColorScheme)
        .readableForegroundHierarchy(effectiveColorScheme)
    }
}

struct SettingsPanelView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: UsageStore
    @ObservedObject var updateStore: AppUpdateStore
    let onOpenPaletteLibrary: () -> Void
    var compact = false
    var showsHeader = true
    @Environment(\.colorScheme) private var colorScheme

    private var language: WidgetLanguage { settings.language }

    var body: some View {
        ZStack {
            if !compact {
                LiquidGlassWindowBackdrop(colorScheme: colorScheme)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if showsHeader {
                        settingsHeader
                    }
                    settingsSection(
                        title: language.text("通用", "General"),
                        detail: language.text("界面偏好", "Interface"),
                        symbol: "slider.horizontal.3"
                    ) {
                        SettingsPickerRow(
                            title: language.text("语言", "Language"),
                            detail: language.text("影响主窗口、浮窗和设置窗口", "Applies to the main window, menu popover, and settings")
                        ) {
                            SettingsSegmentedControl(
                                selection: $settings.language,
                                options: [
                                    SettingsSegmentOption(value: .zh, title: "中文"),
                                    SettingsSegmentOption(value: .en, title: "English"),
                                ],
                                width: settingsAccessoryColumnWidth
                            )
                        }

                        SettingsPickerRow(
                            title: language.text("外观", "Appearance"),
                            detail: language.text("默认跟随系统", "System is the default")
                        ) {
                            SettingsSegmentedControl(
                                selection: $settings.themeMode,
                                options: [
                                    SettingsSegmentOption(value: .system, title: language.text("自动", "System")),
                                    SettingsSegmentOption(value: .light, title: language.text("浅色", "Light")),
                                    SettingsSegmentOption(value: .dark, title: language.text("深色", "Dark")),
                                ],
                                width: settingsAccessoryColumnWidth
                            )
                        }

                        SettingsPickerRow(
                            title: language.text("配色", "Color palette"),
                            detail: language.text("精选内置配色，同时适配浅色与深色", "Curated palettes for both Light and Dark appearances")
                        ) {
                            PaletteSettingsView(settings: settings, onOpenLibrary: onOpenPaletteLibrary)
                                .frame(width: settingsAccessoryColumnWidth)
                        }

                        SettingsPickerRow(
                            title: language.text("透明度", "Transparency"),
                            detail: language.text("调节菜单栏账号面板的玻璃浓度", "Adjusts the glass density of the account popover")
                        ) {
                            SettingsSegmentedControl(
                                selection: $settings.accountMenuTransparency,
                                options: [
                                    SettingsSegmentOption(value: .clear, title: language.text("清晰", "Clear")),
                                    SettingsSegmentOption(value: .standard, title: language.text("标准", "Standard")),
                                    SettingsSegmentOption(value: .frosted, title: language.text("磨砂", "Frosted")),
                                ],
                                width: settingsAccessoryColumnWidth
                            )
                        }

                        SettingsPickerRow(
                            title: language.text("额度环动效", "Quota ring motion"),
                            detail: language.text(
                                "默认仅窗口置前且聚焦；省电仅悬停环带",
                                "Default: frontmost and focused; Power Saving: ring hover only"
                            )
                        ) {
                            SettingsSegmentedControl(
                                selection: $settings.particleAnimationMode,
                                options: [
                                    SettingsSegmentOption(value: .standard, title: language.text("默认", "Default")),
                                    SettingsSegmentOption(value: .powerSaving, title: language.text("省电", "Power Saving")),
                                ],
                                width: settingsAccessoryColumnWidth
                            )
                        }

                        SettingsToggleRow(
                            title: language.text("5 小时暖号", "5-hour warm-up"),
                            detail: language.text(
                                "各账号按自己的重置时间串行执行；周额度不足时暂停",
                                "Run accounts serially at their own reset times; pause on low weekly quota"
                            )
                        ) {
                            SettingsSwitchToggle(
                                isOn: Binding(
                                    get: { store.warmUpSelection.fiveHour },
                                    set: { store.setWarmUpFiveHourEnabled($0) }
                                ))
                        }

                        SettingsToggleRow(
                            title: language.text("7 天暖号", "7-day warm-up"),
                            detail: language.text(
                                "各账号分别跟随自己的 7 天窗口",
                                "Follow each account's own 7-day window"
                            )
                        ) {
                            SettingsSwitchToggle(
                                isOn: Binding(
                                    get: { store.warmUpSelection.sevenDay },
                                    set: { store.setWarmUpSevenDayEnabled($0) }
                                ))
                        }
                    }

                    settingsSection(
                        title: "Runtime",
                        detail: language.text("展示范围", "Display"),
                        symbol: "cpu"
                    ) {
                        SettingsPickerRow(
                            title: language.text("展示 Runtime", "Visible runtimes"),
                            detail: language.text("主窗口和菜单栏浮窗中的 Runtime 范围", "Runtime scope in the main window and menu popover")
                        ) {
                            SettingsRuntimeMultiSelectControl(
                                selectedScopes: settings.visibleRuntimeScopes,
                                language: language
                            ) { scope in
                                settings.setRuntime(scope, visible: !settings.isRuntimeVisible(scope))
                            }
                            .help(runtimeSelectionHelp)
                            .accessibilityLabel(language.text("展示 Runtime", "Visible runtimes"))
                            .accessibilityValue(
                                settings.visibleRuntimeScopes
                                    .map(\.displayName)
                                    .joined(separator: ", ")
                            )
                        }
                    }

                    settingsSection(
                        title: language.text("数据与统计", "Data & Statistics"),
                        detail: language.text("自然日口径", "Calendar-day basis"),
                        symbol: "clock"
                    ) {
                        SettingsPickerRow(
                            title: language.text("统计时区", "Statistics time zone"),
                            detail: statisticsTimeZoneDetail
                        ) {
                            SettingsSegmentedControl(
                                selection: statisticsTimeZoneSelectionBinding,
                                options: [
                                    SettingsSegmentOption(value: .system, title: language.text("跟随系统", "System")),
                                    SettingsSegmentOption(value: .utc, title: "UTC"),
                                    SettingsSegmentOption(value: .fixed, title: language.text("固定", "Fixed")),
                                ],
                                width: settingsAccessoryColumnWidth
                            )
                        }

                        if store.statisticsPreference.selection == .fixed {
                            SettingsPickerRow(
                                title: language.text("固定时区", "Fixed time zone"),
                                detail: language.text("使用 IANA 时区，自动处理夏令时", "Uses an IANA zone and observes daylight saving time")
                            ) {
                                Picker("", selection: statisticsFixedIdentifierBinding) {
                                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                                        Text(identifier).tag(identifier)
                                    }
                                }
                                .labelsHidden()
                                .controlSize(.small)
                                .frame(
                                    width: settingsAccessoryColumnWidth,
                                    height: settingsControlVisualHeight
                                )
                            }
                        }
                    }

                    settingsSection(
                        title: language.text("状态栏", "Menu Bar"),
                        detail: language.text("内容与显示密度", "Content and density"),
                        symbol: "menubar.rectangle"
                    ) {
                        StatusItemSettingsView(settings: settings, store: store)
                    }

                    settingsSection(
                        title: language.text("窗口", "Window"),
                        detail: language.text("主窗口行为", "Main window"),
                        symbol: "macwindow"
                    ) {
                        SettingsToggleRow(
                            title: language.text("保持主窗口置顶", "Keep main window on top"),
                            detail: language.text("适合需要持续观察用量时开启", "Use this when you need the usage view visible")
                        ) {
                            SettingsSwitchToggle(isOn: $settings.keepMainWindowOnTop)
                        }

                        SettingsToggleRow(
                            title: language.text("关闭后继续后台运行", "Keep running after closing the window"),
                            detail: language.text("关闭主窗口会隐藏 Dock 图标，可从菜单栏或快捷键再次打开", "Closing the main window hides the Dock icon; reopen from the menu bar or shortcut")
                        ) {
                            SettingsSwitchToggle(isOn: $settings.keepRunningWhenMainWindowClosed)
                        }

                        SettingsPickerRow(
                            title: language.text("快捷键", "Shortcut"),
                            detail: language.text(
                                "默认 ⌘U；自定义需两个修饰键（含 ⌘ 或 ⌃）；仅能检测独占冲突",
                                "Default: ⌘U. Custom: two modifiers including ⌘ or ⌃; only exclusive conflicts are detected"
                            )
                        ) {
                            HStack(spacing: settingsShortcutControlSpacing) {
                                ShortcutRecorderView(
                                    shortcut: settings.globalShortcut,
                                    language: language,
                                    onRecord: settings.requestGlobalShortcut,
                                    onClear: settings.clearGlobalShortcut
                                )
                                .frame(
                                    width: settingsShortcutRecorderWidth,
                                    height: settingsControlVisualHeight
                                )

                                Button {
                                    settings.resetGlobalShortcut()
                                } label: {
                                    Text(language.text("恢复默认", "Restore Default"))
                                        .font(.system(size: settingsControlFontSize, weight: .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                        .frame(
                                            width: settingsShortcutActionWidth,
                                            height: settingsControlVisualHeight
                                        )
                                }
                                .buttonStyle(.borderless)
                                .disabled(
                                    settings.globalShortcut == .default
                                        && settings.globalShortcutError == nil
                                )
                            }
                            .frame(width: settingsAccessoryColumnWidth, alignment: .trailing)
                        }

                        if let error = settings.globalShortcutError {
                            SettingsErrorRow(
                                title: language.text("快捷键不可用", "Shortcut unavailable"),
                                message: error.message(language: language),
                                currentValue: settings.globalShortcut.map {
                                    language.text("当前仍使用 \($0.displayName)", "Still using \($0.displayName)")
                                } ?? language.text("当前未设置全局快捷键", "No global shortcut is currently set")
                            )
                        }
                    }

                    settingsSection(
                        title: language.text("系统", "System"),
                        detail: language.text("状态与更新", "Status"),
                        symbol: "gearshape.2"
                    ) {
                        SettingsValueRow(
                            title: language.text("当前 Runtime", "Current runtime"),
                            detail: language.text("主窗口数据范围", "Main window data scope"),
                            value: store.selectedRuntimeScope.displayName
                        )
                        SettingsValueRow(
                            title: language.text("计划状态", "Plan"),
                            detail: language.text("来自本机账户读取结果", "Read from the local account result"),
                            value: planLabel
                        )
                        AppUpdateSettingsRows(
                            settings: settings,
                            updateStore: updateStore,
                            language: language
                        )
                    }
                }
                .padding(.horizontal, compact ? 12 : 20)
                .padding(.top, compact ? 12 : settingsContentTopInset)
                .padding(.bottom, 20)
            }
        }
        .frame(width: compact ? CodexAccountMenuView.preferredSize.width : 480, alignment: .topLeading)
        .appVisualEnvironment(
            catalog: settings.paletteCatalog,
            paletteID: settings.paletteID,
            appearance: PaletteAppearance(colorScheme)
        )
        .readableForegroundHierarchy(colorScheme)
    }

    private var statisticsTimeZoneSelectionBinding: Binding<StatisticsTimeZoneSelection> {
        Binding(
            get: { store.statisticsPreference.selection },
            set: { selection in
                var preference = store.statisticsPreference
                preference.selection = selection
                store.updateStatisticsTimeZone(preference)
            }
        )
    }

    private var statisticsFixedIdentifierBinding: Binding<String> {
        Binding(
            get: { store.statisticsPreference.fixedIdentifier },
            set: { identifier in
                store.updateStatisticsTimeZone(
                    StatisticsTimeZonePreference(selection: .fixed, fixedIdentifier: identifier)
                )
            }
        )
    }

    private var statisticsTimeZoneDetail: String {
        if let message = store.statisticsTransitionMessage {
            return message
        }
        let identity = store.multiRuntimeSnapshot.statisticsIdentity
        switch identity.preference.selection {
        case .system:
            return language.text(
                "默认按系统自然日统计 · \(identity.resolvedIdentifier)",
                "Uses the system calendar day · \(identity.resolvedIdentifier)"
            )
        case .utc:
            return language.text("UTC 日界线，便于对照官方", "UTC day boundary for easier official comparison")
        case .fixed:
            return identity.resolvedIdentifier
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text("设置", "Settings"))
                    .font(.system(size: 22, weight: .semibold))
                Text(language.text("账号、额度与运行时控制", "Accounts, quotas, and runtimes"))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("NEXT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        detail: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: settingsSectionTitleFontSize, weight: .semibold))
                    Text(detail)
                        .font(.system(size: settingsSectionDetailFontSize, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider()
                .padding(.leading, 43)

            VStack(spacing: 0) {
                content()
            }
        }
        .cardBackground(cornerRadius: 12, elevated: false)
    }

    private var planLabel: String {
        store.snapshot.account?.planType?.uppercased() ?? "LOCAL"
    }

    private var runtimeSelectionHelp: String {
        language.text(
            "点击切换展示范围；至少需要保留一个 Runtime",
            "Click to change visibility; at least one runtime must stay visible"
        )
    }
}

struct SettingsPickerRow<Control: View>: View {
    let title: String
    let detail: String
    let control: Control

    init(title: String, detail: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        SettingsBaseRow(title: title, detail: detail) {
            control
        }
    }
}

struct SettingsSegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: Value { value }
}

struct SettingsSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [SettingsSegmentOption<Value>]
    let width: CGFloat

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options) { option in
                Text(option.title).tag(option.value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        .frame(width: width, height: settingsControlVisualHeight)
    }
}

struct SettingsRuntimeMultiSelectControl: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.visualTokens) private var visualTokens
    let selectedScopes: [RuntimeScope]
    let language: WidgetLanguage
    let onToggle: (RuntimeScope) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(RuntimeScope.allCases.enumerated()), id: \.element.id) { index, scope in
                Button {
                    onToggle(scope)
                } label: {
                    HStack(spacing: 6) {
                        RuntimeLogoView(scope: scope, size: 16)
                        Text(label(for: scope))
                            .font(.system(size: settingsControlFontSize, weight: isSelected(scope) ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .foregroundStyle(isSelected(scope) ? Color.white : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: settingsSegmentHeight)
                    .background(
                        RoundedRectangle(cornerRadius: settingsControlCornerRadius, style: .continuous)
                            .fill(isSelected(scope) ? visualTokens.accent.primary.color : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(for: scope))
                .accessibilityValue(isSelected(scope) ? language.text("已选择", "Selected") : language.text("未选择", "Not selected"))

                if index < RuntimeScope.allCases.count - 1 {
                    Rectangle()
                        .fill(FixedVisualPalette.controlStroke(colorScheme))
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 1)
                }
            }
        }
        .padding(3)
        .frame(width: settingsAccessoryColumnWidth, height: settingsControlVisualHeight)
        .background(
            RoundedRectangle(cornerRadius: settingsControlCornerRadius, style: .continuous)
                .fill(FixedVisualPalette.controlFill(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: settingsControlCornerRadius, style: .continuous)
                        .strokeBorder(FixedVisualPalette.controlStroke(colorScheme), lineWidth: 0.8)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: settingsControlCornerRadius, style: .continuous))
    }

    private func isSelected(_ scope: RuntimeScope) -> Bool {
        selectedScopes.contains(scope)
    }

    private func label(for scope: RuntimeScope) -> String {
        switch scope {
        case .codex:
            return "Codex"
        case .claudeCode:
            return language.text("Claude Code", "Claude Code")
        }
    }
}

struct SettingsSwitchToggle: View {
    @Environment(\.visualTokens) private var visualTokens
    let isOn: Binding<Bool>
    var isDisabled = false
    var help: String?

    var body: some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.regular)
            .tint(visualTokens.accent.primary.color)
            .frame(width: settingsSwitchWidth, alignment: .trailing)
            .disabled(isDisabled)
            .help(help ?? "")
    }
}

struct SettingsToggleRow<Control: View>: View {
    let title: String
    let detail: String
    let control: Control

    init(title: String, detail: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        SettingsBaseRow(title: title, detail: detail) {
            control
        }
    }
}

struct SettingsValueRow: View {
    let title: String
    let detail: String
    let value: String

    var body: some View {
        SettingsBaseRow(title: title, detail: detail) {
            Text(value)
                .font(.system(size: settingsControlFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

struct SettingsErrorRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let message: String
    let currentValue: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FixedVisualPalette.statusDanger)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: settingsRowTitleFontSize, weight: .semibold))
                    .foregroundStyle(FixedVisualPalette.statusDanger)
                Text(message)
                    .font(.system(size: settingsRowDetailFontSize, weight: .regular))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(currentValue)
                    .font(.system(size: settingsRowDetailFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: settingsControlCornerRadius, style: .continuous)
                .fill(FixedVisualPalette.statusDangerFill(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: settingsControlCornerRadius, style: .continuous)
                        .strokeBorder(FixedVisualPalette.statusDangerStroke(colorScheme), lineWidth: 0.8)
                )
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

struct SettingsBaseRow<Accessory: View>: View {
    let title: String
    let detail: String
    let accessory: Accessory

    init(title: String, detail: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.detail = detail
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: settingsRowTitleFontSize, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.system(size: settingsRowDetailFontSize, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            accessory
                .frame(width: settingsAccessoryColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 12)
        }
    }
}

struct SectionBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        FixedVisualPalette.sectionFill(
                            colorScheme,
                            reduceTransparency: reduceTransparency
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                FixedVisualPalette.sectionStroke(
                                    colorScheme,
                                    increasedContrast: colorSchemeContrast == .increased
                                ),
                                lineWidth: colorSchemeContrast == .increased ? 1.0 : 0.8
                            )
                    )
            )
    }
}

struct CardBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let cornerRadius: CGFloat
    let elevated: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        FixedVisualPalette.cardFill(
                            colorScheme,
                            elevated: elevated,
                            reduceTransparency: reduceTransparency
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                FixedVisualPalette.cardStroke(
                                    colorScheme,
                                    elevated: elevated,
                                    increasedContrast: colorSchemeContrast == .increased
                                ),
                                lineWidth: colorSchemeContrast == .increased ? 1.0 : 0.8
                            )
                    )
            )
    }
}

extension View {
    func readableForegroundHierarchy(_ colorScheme: ColorScheme) -> some View {
        foregroundStyle(
            Color.primary,
            FixedVisualPalette.secondaryText(colorScheme),
            FixedVisualPalette.tertiaryText(colorScheme)
        )
    }

    func sectionBackground() -> some View {
        modifier(SectionBackgroundModifier())
    }

    func cardBackground(cornerRadius: CGFloat = 10, elevated: Bool = false) -> some View {
        modifier(CardBackgroundModifier(cornerRadius: cornerRadius, elevated: elevated))
    }
}
