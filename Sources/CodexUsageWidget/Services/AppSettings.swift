import Cocoa
import Combine
import SwiftUI

enum WidgetLanguage: String, CaseIterable, Equatable {
    case zh
    case en

    static let storageKey = "CodexManagerNext.interfaceLanguage"

    static var automatic: WidgetLanguage {
        let identifier = TimeZone.current.identifier
        let chineseTimeZones: Set<String> = [
            "Asia/Shanghai",
            "Asia/Chongqing",
            "Asia/Harbin",
            "Asia/Urumqi",
            "Asia/Hong_Kong",
            "Asia/Macau",
            "Asia/Taipei",
        ]
        return chineseTimeZones.contains(identifier) ? .zh : .en
    }

    var isChinese: Bool { self == .zh }

    static func storedOrAutomatic(defaults: UserDefaults = .standard) -> WidgetLanguage {
        guard let rawValue = defaults.string(forKey: storageKey),
            let language = WidgetLanguage(rawValue: rawValue)
        else { return .automatic }
        return language
    }

    func persist(defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    func text(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }
}

enum WidgetThemeMode: String, CaseIterable, Equatable {
    case system
    case light
    case dark

    static let storageKey = "CodexManagerNext.interfaceThemeMode"

    static func storedOrAutomatic(defaults: UserDefaults = .standard) -> WidgetThemeMode {
        guard let rawValue = defaults.string(forKey: storageKey),
            let mode = WidgetThemeMode(rawValue: rawValue)
        else { return .system }
        return mode
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func persist(defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    func applyAppearance() {
        switch self {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum ParticleAnimationMode: String, CaseIterable, Equatable {
    case standard = "default"
    case powerSaving = "powerSaving"

    static let storageKey = "CodexManagerNext.particleAnimationMode"

    static func storedOrDefault(defaults: UserDefaults = .standard) -> ParticleAnimationMode {
        guard let rawValue = defaults.string(forKey: storageKey),
            let mode = ParticleAnimationMode(rawValue: rawValue)
        else { return .standard }
        return mode
    }

    func persist(defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

enum AccountMenuTransparency: String, CaseIterable, Equatable {
    case clear
    case standard
    case frosted

    static let storageKey = "CodexManagerNext.accountMenuTransparency"

    static func storedOrDefault(defaults: UserDefaults = .standard) -> AccountMenuTransparency {
        guard let rawValue = defaults.string(forKey: storageKey),
            let value = AccountMenuTransparency(rawValue: rawValue)
        else { return .standard }
        return value
    }

    func persist(defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

enum PaletteSelectionResult: Equatable {
    case selected
    case unavailable
}

struct PaletteFallbackNotice: Equatable {
    let unavailableID: String
}

final class AppSettings: ObservableObject {
    private static let keepMainWindowOnTopKey = "CodexManagerNext.keepMainWindowOnTop"
    private static let keepRunningWhenMainWindowClosedKey = "CodexManagerNext.keepRunningWhenMainWindowClosed"
    private static let visibleRuntimeScopesKey = "CodexManagerNext.visibleRuntimeScopes"
    private static let automaticUpdateChecksEnabledKey = "CodexManagerNext.update.autoCheckEnabled"
    private static let skippedUpdateVersionKey = "CodexManagerNext.update.skippedVersion"
    private static let paletteIDKey = "CodexManagerNext.paletteID"

    private let defaults: UserDefaults
    let paletteCatalog: PaletteCatalog

    @Published var language: WidgetLanguage {
        didSet {
            language.persist(defaults: defaults)
        }
    }

    @Published var themeMode: WidgetThemeMode {
        didSet {
            themeMode.persist(defaults: defaults)
            themeMode.applyAppearance()
        }
    }

    @Published var particleAnimationMode: ParticleAnimationMode {
        didSet {
            particleAnimationMode.persist(defaults: defaults)
        }
    }

    @Published var usageTrendWindow: UsageTrendWindow {
        didSet {
            usageTrendWindow.persist(defaults: defaults)
        }
    }

    @Published var accountMenuTransparency: AccountMenuTransparency {
        didSet {
            accountMenuTransparency.persist(defaults: defaults)
        }
    }

    @Published private(set) var paletteID: String
    @Published private(set) var paletteFallbackNotice: PaletteFallbackNotice?

    @Published var keepMainWindowOnTop: Bool {
        didSet {
            defaults.set(keepMainWindowOnTop, forKey: Self.keepMainWindowOnTopKey)
        }
    }

    @Published var keepRunningWhenMainWindowClosed: Bool {
        didSet {
            defaults.set(keepRunningWhenMainWindowClosed, forKey: Self.keepRunningWhenMainWindowClosedKey)
        }
    }

    @Published var automaticUpdateChecksEnabled: Bool {
        didSet {
            defaults.set(automaticUpdateChecksEnabled, forKey: Self.automaticUpdateChecksEnabledKey)
        }
    }

    @Published private(set) var skippedUpdateVersion: String? {
        didSet {
            if let skippedUpdateVersion {
                defaults.set(skippedUpdateVersion, forKey: Self.skippedUpdateVersionKey)
            } else {
                defaults.removeObject(forKey: Self.skippedUpdateVersionKey)
            }
        }
    }

    @Published private(set) var visibleRuntimeScopes: [RuntimeScope] {
        didSet {
            defaults.set(visibleRuntimeScopes.map(\.runtimeId), forKey: Self.visibleRuntimeScopesKey)
        }
    }

    @Published private(set) var statusItemPreferences: StatusItemPreferences
    @Published private(set) var globalShortcut: GlobalShortcut?
    @Published private(set) var globalShortcutError: GlobalShortcutError?
    var globalShortcutRegistration: ((GlobalShortcut) -> Result<Void, GlobalShortcutRegistrationFailure>)?
    var globalShortcutUnregistration: (() -> Result<Void, GlobalShortcutRegistrationFailure>)?

    init(defaults: UserDefaults = .standard, paletteCatalog: PaletteCatalog = .loadFromMainBundle()) {
        self.defaults = defaults
        self.paletteCatalog = paletteCatalog
        let storedPaletteID = defaults.string(forKey: Self.paletteIDKey)
        if let storedPaletteID, paletteCatalog.contains(storedPaletteID) {
            paletteID = storedPaletteID
            paletteFallbackNotice = nil
        } else {
            paletteID = PaletteCatalog.defaultPaletteID
            paletteFallbackNotice = storedPaletteID.map(PaletteFallbackNotice.init(unavailableID:))
            defaults.set(PaletteCatalog.defaultPaletteID, forKey: Self.paletteIDKey)
        }
        language = WidgetLanguage.storedOrAutomatic(defaults: defaults)
        themeMode = WidgetThemeMode.storedOrAutomatic(defaults: defaults)
        particleAnimationMode = ParticleAnimationMode.storedOrDefault(defaults: defaults)
        usageTrendWindow = UsageTrendWindow.storedOrDefault(defaults: defaults)
        accountMenuTransparency = AccountMenuTransparency.storedOrDefault(defaults: defaults)
        keepMainWindowOnTop = defaults.bool(forKey: Self.keepMainWindowOnTopKey)
        if defaults.object(forKey: Self.keepRunningWhenMainWindowClosedKey) == nil {
            keepRunningWhenMainWindowClosed = true
        } else {
            keepRunningWhenMainWindowClosed = defaults.bool(forKey: Self.keepRunningWhenMainWindowClosedKey)
        }
        if defaults.object(forKey: Self.automaticUpdateChecksEnabledKey) == nil {
            automaticUpdateChecksEnabled = true
        } else {
            automaticUpdateChecksEnabled = defaults.bool(forKey: Self.automaticUpdateChecksEnabledKey)
        }
        skippedUpdateVersion = defaults.string(forKey: Self.skippedUpdateVersionKey)
        visibleRuntimeScopes = Self.storedVisibleRuntimeScopes(defaults: defaults)
        statusItemPreferences = StatusItemPreferencesStore.load(defaults: defaults)
        let storedShortcut = GlobalShortcut.load(defaults: defaults)
        if let storedShortcut, storedShortcut.validationError != nil {
            globalShortcut = .default
            GlobalShortcut.default.save(defaults: defaults)
        } else {
            globalShortcut = storedShortcut
        }
        globalShortcutError = nil
    }

    @discardableResult
    func selectPalette(_ id: String) -> PaletteSelectionResult {
        guard paletteCatalog.contains(id) else {
            paletteFallbackNotice = PaletteFallbackNotice(unavailableID: id)
            return .unavailable
        }
        paletteID = id
        paletteFallbackNotice = nil
        defaults.set(id, forKey: Self.paletteIDKey)
        return .selected
    }

    func resetPalette() {
        _ = selectPalette(PaletteCatalog.defaultPaletteID)
    }

    func isRuntimeVisible(_ scope: RuntimeScope) -> Bool {
        visibleRuntimeScopes.contains(scope)
    }

    @discardableResult
    func setRuntime(_ scope: RuntimeScope, visible: Bool) -> Bool {
        if visible {
            visibleRuntimeScopes = Self.orderedRuntimeScopes(Set(visibleRuntimeScopes + [scope]))
            return true
        }
        guard visibleRuntimeScopes.count > 1 else {
            return false
        }
        visibleRuntimeScopes = visibleRuntimeScopes.filter { $0 != scope }
        return true
    }

    private static func storedVisibleRuntimeScopes(defaults: UserDefaults) -> [RuntimeScope] {
        guard let identifiers = defaults.array(forKey: visibleRuntimeScopesKey) as? [String] else {
            return RuntimeScope.allCases
        }
        let scopes = identifiers.compactMap(RuntimeScope.storedIdentifier)
        let ordered = orderedRuntimeScopes(Set(scopes))
        return ordered.isEmpty ? RuntimeScope.allCases : ordered
    }

    private static func orderedRuntimeScopes(_ scopes: Set<RuntimeScope>) -> [RuntimeScope] {
        RuntimeScope.allCases.filter { scopes.contains($0) }
    }

    @discardableResult
    func updateStatusItemPreferences(
        _ mutation: (inout StatusItemPreferences) -> Void
    ) -> Result<Void, StatusItemPreferenceError> {
        var candidate = statusItemPreferences
        mutation(&candidate)
        if let error = candidate.validationError() {
            return .failure(error)
        }
        candidate = candidate.normalized()
        guard candidate != statusItemPreferences else {
            return .success(())
        }
        statusItemPreferences = candidate
        StatusItemPreferencesStore.save(candidate, defaults: defaults)
        return .success(())
    }

    func resetStatusItemPreferences() {
        StatusItemPreferencesStore.reset(defaults: defaults)
        statusItemPreferences = .accountRing
    }

    @discardableResult
    func requestGlobalShortcut(_ shortcut: GlobalShortcut) -> Bool {
        if let current = globalShortcut, shortcut.matchesRegistration(of: current) {
            globalShortcut = shortcut
            shortcut.save(defaults: defaults)
            globalShortcutError = nil
            return true
        }
        if let error = shortcut.validationError {
            globalShortcutError = .invalid(error)
            return false
        }
        guard let result = globalShortcutRegistration?(shortcut) else {
            globalShortcutError = .registrationFailed
            return false
        }
        switch result {
        case .success:
            break
        case .failure(.occupied):
            globalShortcutError = .occupied
            return false
        case .failure(.failed):
            globalShortcutError = .registrationFailed
            return false
        }
        globalShortcut = shortcut
        shortcut.save(defaults: defaults)
        globalShortcutError = nil
        return true
    }

    func resetGlobalShortcut() {
        requestGlobalShortcut(.default)
    }

    func clearGlobalShortcut() {
        guard let globalShortcutUnregistration else {
            globalShortcutError = .unregistrationFailed
            return
        }
        guard case .success = globalShortcutUnregistration() else {
            globalShortcutError = .unregistrationFailed
            return
        }
        globalShortcut = nil
        GlobalShortcut.clear(defaults: defaults)
        globalShortcutError = nil
    }

    func handleInitialGlobalShortcutFailure(defaultRegistered: Bool) {
        if defaultRegistered {
            globalShortcut = .default
            globalShortcutError = .savedShortcutUnavailableUsingDefault
        } else {
            globalShortcut = nil
            globalShortcutError = .noShortcutAvailable
        }
    }

    func skipUpdateVersion(_ version: String) {
        skippedUpdateVersion = version
    }

    func clearSkippedUpdateVersion() {
        skippedUpdateVersion = nil
    }
}
