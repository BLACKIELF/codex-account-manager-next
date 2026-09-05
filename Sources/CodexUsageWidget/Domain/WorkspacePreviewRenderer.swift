import AppKit
import SwiftUI

/// Render the production SwiftUI views at 2x using synthetic accounts only.
enum WorkspacePreviewRenderer {
    static func fixtureStore(accountCount: Int, root: URL) -> UsageStore {
        let now = Date()
        let fiveHour = RateWindow(usedPercent: 18, windowDurationMins: 300, resetsAt: now.addingTimeInterval(10_800))
        let sevenDay = RateWindow(usedPercent: 37, windowDurationMins: 10_080, resetsAt: now.addingTimeInterval(259_200))
        let profiles = (0..<max(accountCount, 1)).map { index in
            CodexProfile(
                id: accountCount == 0 ? "system" : "preview-\(index)",
                name: accountCount == 0 ? "当前 Codex" : ["我的工作账号", "创作账号", "备用账号"][index % 3],
                remark: accountCount == 0 ? "当前 Codex" : ["我的工作账号", "创作账号", "备用账号"][index % 3],
                codexHomePath: root.appendingPathComponent("profile-\(index)").path,
                isSystemProfile: accountCount == 0, createdAt: now,
                lastSnapshot: CodexAccountSnapshot(
                    accountType: "chatgpt", planType: "plus", email: "preview-\(index)@example.invalid",
                    limitId: "codex", limitName: "Codex", fiveHour: CodexQuotaWindowSnapshot(fiveHour),
                    sevenDay: CodexQuotaWindowSnapshot(sevenDay), monthly: nil,
                    availableResetCredits: 2, resetCreditExpiries: [now.addingTimeInterval(864_000)],
                    fetchedAt: now, appServerVersion: nil
                ),
                officialProfile: CodexOfficialProfileSnapshot(
                    accountEmail: nil, displayName: nil, username: nil,
                    lifetimeTokens: 82_400_000, peakDailyTokens: nil, planType: "plus",
                    subscriptionActiveUntil: now.addingTimeInterval(1_814_400), statsAsOf: now, fetchedAt: now
                ),
                executionPreference: accountCount == 0 ? nil : .init(model: .astra, reasoningEffort: .max, serviceTier: .standard)
            )
        }
        return UsageStore(
            previewProfiles: profiles,
            snapshot: UsageSnapshot(
                refreshedAt: now, account: AccountInfo(type: "chatgpt", planType: "plus", emailPresent: false),
                limitId: "codex", limitName: "Codex", quotaReadSucceeded: true,
                fiveHourQuota: fiveHour, sevenDayQuota: sevenDay, monthlyQuota: nil,
                credits: nil, cloudLifetimeTokens: 82_400_000, local: nil, taskBoard: nil, messages: []
            ),
            isolatedRoot: root
        )
    }

    static func render(to directory: URL) -> Bool {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("next-ui-preview-\(UUID().uuidString)")
        let suiteName = "CodexManagerNext.workspace-preview.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return false }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let catalog = PaletteCatalog.loadFromMainBundle()
            let settings = AppSettings(defaults: defaults, paletteCatalog: catalog)
            for scheme in [ColorScheme.dark, .light] {
                settings.themeMode = scheme == .dark ? .dark : .light
                let theme = scheme == .dark ? "dark" : "light"
                let tokens = catalog.resolve(id: settings.paletteID, appearance: scheme == .dark ? .dark : .light)
                for count in [0, 1, 3] {
                    let name = count == 0 ? "single-system" : count == 1 ? "single-account" : "multi-account"
                    let store = fixtureStore(accountCount: count, root: root.appendingPathComponent("\(theme)-\(count)"))
                    for width: CGFloat in [860, 1080] {
                        let size = CGSize(width: width, height: 760)
                        let view = CodexAccountManagerView(store: store, settings: settings, paletteCatalog: catalog)
                            .frame(width: size.width, height: size.height)
                            .environment(\.colorScheme, scheme)
                        try renderView(view, size: size, scheme: scheme, to: directory.appendingPathComponent("\(name)-\(theme)-\(Int(width)).png"))
                    }
                    if count < 2 {
                        let updateStore = AppUpdateStore(settings: settings)
                        let menu = CodexAccountMenuView(
                            store: store, settings: settings, updateStore: updateStore, paletteCatalog: catalog,
                            openFullWindow: {}, openPaletteLibrary: {}, quit: {}
                        )
                        try renderView(menu, size: CodexAccountMenuView.preferredSize, scheme: scheme, to: directory.appendingPathComponent("\(name)-menu-\(theme).png"))
                    }
                }
                let editor = ExecutionPreferenceControl(
                    preference: .init(model: .astra, reasoningEffort: .max, serviceTier: .standard),
                    inlineEditor: true, onSave: { _, _ in }
                )
                .environment(\.visualTokens, tokens)
                .environment(\.colorScheme, scheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FixedVisualPalette.windowScrim(scheme, reduceTransparency: true))
                try renderView(editor, size: CGSize(width: 400, height: 470), scheme: scheme, to: directory.appendingPathComponent("astra-model-\(theme).png"))
            }
            return true
        } catch {
            print("workspace preview render failed")
            return false
        }
    }

    static func renderView<Content: View>(_ view: Content, size: CGSize, scheme: ColorScheme, to url: URL) throws {
        let host = NSHostingView(rootView: view)
        // An unattached host rasterizes its SwiftUI layers at 1x. Attach to a
        // non-presented window so AppKit supplies the display's backing scale.
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        defer { window.contentView = nil }
        host.frame = NSRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        host.layoutSubtreeIfNeeded()
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            )
        else { throw CocoaError(.fileWriteUnknown) }
        bitmap.size = size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url, options: .atomic)
    }
}
