import Carbon.HIToolbox
import Cocoa
import Combine
import SwiftUI

private func fourCharCode(_ value: String) -> OSType {
    value.utf8.reduce(0) { result, byte in
        (result << 8) + OSType(byte)
    }
}

final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
}

final class GlassHostingContainer<Content: View>: NSView {
    private let cornerRadius: CGFloat

    init(rootView: Content, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = cornerRadius

        let host = DraggableHostingView(rootView: rootView)
        host.frame = bounds
        host.autoresizingMask = [.width, .height]

        #if compiler(>=6.2) && CAMNEXT_HAS_LIQUID_GLASS
            if #available(macOS 26.0, *) {
                let glass = NSGlassEffectView(frame: bounds)
                glass.autoresizingMask = [.width, .height]
                glass.cornerRadius = cornerRadius
                glass.style = .regular
                glass.tintColor = nil
                glass.contentView = host
                addSubview(glass)
            } else {
                installMaterialFallback(host: host)
            }
        #else
            installMaterialFallback(host: host)
        #endif
    }

    private func installMaterialFallback(host: NSView) {
        let material = NSVisualEffectView(frame: bounds)
        material.autoresizingMask = [.width, .height]
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .followsWindowActiveState
        material.wantsLayer = true
        material.layer?.cornerRadius = cornerRadius
        material.layer?.masksToBounds = true
        material.addSubview(host)
        addSubview(material)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool { true }
}

final class MainAppWindow: NSWindow {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Codex Account Manager Next"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        acceptsMouseMovedEvents = true
        collectionBehavior = [.fullScreenAuxiliary]
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private let startupPerformanceSpan = PerformanceMonitor.shared.begin(.appStartup)
    private let store = UsageStore()
    private let paletteCatalog = PaletteCatalog.loadFromMainBundle()
    private lazy var settings = AppSettings(paletteCatalog: paletteCatalog)
    private lazy var updateStore = AppUpdateStore(settings: settings)
    private var window: MainAppWindow?
    private var paletteLibraryWindow: NSWindow?
    private var titlebarToolbarController: NSTitlebarAccessoryViewController?
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var statusPopoverEventMonitors: [Any] = []
    private var statusItemAppearanceObservation: NSKeyValueObservation?
    private var activeSpaceObserver: NSObjectProtocol?
    private var globalHotKeyRef: EventHotKeyRef?
    private var globalHotKeyHandler: EventHandlerRef?
    private var cancellables = Set<AnyCancellable>()
    private let statusItemPresentationBuilder = StatusItemPresentationBuilder()
    private let statusItemRenderer = StatusItemRenderer()
    private var lastRenderedStatusItemPresentation: StatusItemPresentation?
    private var lastRenderedStatusItemAppearanceName: NSAppearance.Name?
    private var lastRenderedStatusItemPaletteIdentity: PaletteRenderIdentity?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        settings.themeMode.applyAppearance()
        setupMainMenu()
        debugLog("app launched")

        createMainWindow()
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTaskBoardPollingActivity()
        }
        setupStatusItemIfNeeded()
        observeStatusItemUsage()
        observeSettings()
        settings.globalShortcutRegistration = { [weak self] shortcut in
            self?.replaceGlobalHotKey(with: shortcut) ?? .failure(.failed)
        }
        settings.globalShortcutUnregistration = { [weak self] in
            self?.unregisterGlobalHotKeyReference() ?? .failure(.failed)
        }
        if let shortcut = settings.globalShortcut,
            !registerGlobalHotKey(shortcut)
        {
            let defaultRegistered =
                shortcut == .default
                ? false
                : registerGlobalHotKey(.default)
            settings.handleInitialGlobalShortcutFailure(defaultRegistered: defaultRegistered)
        } else if settings.globalShortcut == nil {
            _ = installGlobalHotKeyHandler()
        }
        if let argumentIndex = CommandLine.arguments.firstIndex(of: "--switch-profile-id"),
            CommandLine.arguments.indices.contains(argumentIndex + 1)
        {
            store.stageLaunchProfileID(CommandLine.arguments[argumentIndex + 1])
        }
        store.updateVisibleRuntimeScopes(settings.visibleRuntimeScopes)
        store.start()
        showMainWindow()
        PerformanceMonitor.shared.end(startupPerformanceSpan)
    }

    private func createMainWindow() {
        let width = CodexAccountManagerView.defaultWidth
        let height = CodexAccountManagerView.defaultHeight
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = CGPoint(
            x: max(screenFrame.minX + 16, screenFrame.maxX - width - 28),
            y: max(screenFrame.minY + 16, screenFrame.maxY - height - 36)
        )

        let mainWindow = MainAppWindow(contentRect: NSRect(origin: origin, size: CGSize(width: width, height: height)))
        mainWindow.delegate = self
        mainWindow.minSize = CGSize(width: CodexAccountManagerView.minWidth, height: CodexAccountManagerView.minHeight)
        mainWindow.maxSize = CGSize(width: CodexAccountManagerView.maxWidth, height: .greatestFiniteMagnitude)
        mainWindow.contentMinSize = mainWindow.minSize
        mainWindow.contentMaxSize = mainWindow.maxSize
        mainWindow.contentView = GlassHostingContainer(
            rootView: CodexAccountManagerView(
                store: store,
                settings: settings,
                paletteCatalog: paletteCatalog
            ),
            cornerRadius: CodexAccountManagerView.windowCornerRadius
        )
        installTitlebarToolbar(on: mainWindow)
        _ = mainWindow.setFrameAutosaveName("CodexAccountManagerNext.mainWindow")
        window = mainWindow
        applyMainWindowLevel()
    }

    private func installTitlebarToolbar(on window: NSWindow) {
        let toolbarView = NSHostingView(
            rootView: TitlebarToolbarView(
                settings: settings,
                onOpenSettings: { [weak self] in
                    self?.openSettingsWindow()
                }
            )
        )
        toolbarView.frame = NSRect(x: 0, y: 0, width: CodexAccountManagerView.defaultWidth - 24, height: 44)

        let controller = NSTitlebarAccessoryViewController()
        controller.layoutAttribute = .right
        controller.view = toolbarView
        window.addTitlebarAccessoryViewController(controller)
        titlebarToolbarController = controller
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        store.isLaunchingCodex ? .terminateCancel : .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        closeStatusPopover()
        statusItemAppearanceObservation = nil
        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
            self.activeSpaceObserver = nil
        }
        unregisterGlobalHotKey()
        store.stop()
    }

    func toggleMainWindow() {
        guard let window else { return }

        if window.isVisible, !window.isMiniaturized, window.isKeyWindow {
            window.orderOut(nil)
            updateTaskBoardPollingActivity()
            return
        }

        showMainWindow()
    }

    func applicationDidResignActive(_ notification: Notification) {
        updateTaskBoardPollingActivity()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updateTaskBoardPollingActivity()
    }

    func applicationDidHide(_ notification: Notification) {
        updateTaskBoardPollingActivity()
    }

    func applicationDidUnhide(_ notification: Notification) {
        updateTaskBoardPollingActivity()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window {
            if settings.keepRunningWhenMainWindowClosed {
                hideMainWindowAfterClose()
            } else {
                NSApp.terminate(nil)
            }
            return false
        }
        return true
    }

    func windowDidMiniaturize(_ notification: Notification) {
        updateTaskBoardPollingActivity()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        updateTaskBoardPollingActivity()
    }

    func windowDidResignKey(_ notification: Notification) {
        updateTaskBoardPollingActivity()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        updateTaskBoardPollingActivity()
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        updateTaskBoardPollingActivity()
    }

    private func showMainWindow() {
        guard let window else { return }
        NSApp.setActivationPolicy(.regular)
        setupStatusItemIfNeeded()
        closeStatusPopover()
        paletteLibraryWindow?.orderOut(nil)
        applyMainWindowLevel()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updateTaskBoardPollingActivity()
    }

    private func hideMainWindowAfterClose() {
        closeStatusPopover()
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        updateTaskBoardPollingActivity()
    }

    private func applyMainWindowLevel() {
        window?.level = settings.keepMainWindowOnTop ? .floating : .normal
    }

    @objc private func openSettingsFromMenu() {
        openSettingsWindow()
    }

    @objc private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func setupMainMenu() {
        let language = settings.language
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Codex Account Manager Next")
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            NSMenuItem(
                title: language.text("关于 Codex Account Manager Next", "About Codex Account Manager Next"),
                action: #selector(showAboutPanel),
                keyEquivalent: ""
            ))
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: language.text("设置…", "Settings..."),
                action: #selector(openSettingsFromMenu),
                keyEquivalent: ","
            ))
        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: language.text("隐藏 Codex Account Manager Next", "Hide Codex Account Manager Next"),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApp
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: language.text("隐藏其他", "Hide Others"),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        hideOthersItem.target = NSApp
        appMenu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: language.text("全部显示", "Show All"),
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        showAllItem.target = NSApp
        appMenu.addItem(showAllItem)
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: language.text("退出 Codex Account Manager Next", "Quit Codex Account Manager Next"),
                action: #selector(quitFromMenu),
                keyEquivalent: "q"
            ))

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: language.text("窗口", "Window"))
        windowMenuItem.submenu = windowMenu
        let minimizeItem = NSMenuItem(
            title: language.text("最小化", "Minimize"),
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(minimizeItem)
        let bringAllItem = NSMenuItem(
            title: language.text("全部前置", "Bring All to Front"),
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        bringAllItem.target = NSApp
        windowMenu.addItem(bringAllItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func openSettingsWindow() {
        closeStatusPopover()
        showStatusPopover(initialScreen: .settings)
    }

    private func openPaletteLibraryWindow() {
        closeStatusPopover()
        window?.orderOut(nil)
        if paletteLibraryWindow == nil {
            let paletteLibraryWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 320),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            paletteLibraryWindow.title = settings.language.text("配色库", "Palette Library")
            paletteLibraryWindow.titleVisibility = .hidden
            paletteLibraryWindow.titlebarAppearsTransparent = true
            paletteLibraryWindow.isReleasedWhenClosed = false
            paletteLibraryWindow.isOpaque = false
            paletteLibraryWindow.backgroundColor = .clear
            paletteLibraryWindow.hasShadow = true
            paletteLibraryWindow.isMovableByWindowBackground = true
            paletteLibraryWindow.acceptsMouseMovedEvents = true
            paletteLibraryWindow.delegate = self
            paletteLibraryWindow.contentMinSize = NSSize(width: 660, height: 320)
            paletteLibraryWindow.contentView = GlassHostingContainer(
                rootView: PaletteLibraryView(settings: settings),
                cornerRadius: 20
            )
            paletteLibraryWindow.center()
            self.paletteLibraryWindow = paletteLibraryWindow
        }

        guard let paletteLibraryWindow else { return }
        NSApp.setActivationPolicy(.regular)
        paletteLibraryWindow.title = settings.language.text("配色库", "Palette Library")
        if paletteLibraryWindow.isMiniaturized {
            paletteLibraryWindow.deminiaturize(nil)
        }
        paletteLibraryWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func observeSettings() {
        settings.$keepMainWindowOnTop
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyMainWindowLevel()
            }
            .store(in: &cancellables)

        settings.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] language in
                self?.paletteLibraryWindow?.title = language.text("配色库", "Palette Library")
                self?.setupMainMenu()
                self?.updateStatusItem()
            }
            .store(in: &cancellables)

        settings.$themeMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)

        settings.$paletteID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.lastRenderedStatusItemPaletteIdentity = nil
                self?.updateStatusItem()
            }
            .store(in: &cancellables)

        settings.$visibleRuntimeScopes
            .receive(on: RunLoop.main)
            .sink { [weak self] scopes in
                guard let self else { return }
                self.store.updateVisibleRuntimeScopes(scopes)
                self.updateStatusItem()
            }
            .store(in: &cancellables)

        settings.$statusItemPreferences
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)

        settings.$globalShortcut
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)

    }

    @objc private func statusItemClicked() {
        toggleStatusPopover()
    }

    private func toggleStatusPopover() {
        if statusPopover?.isShown == true {
            closeStatusPopover()
            return
        }

        showStatusPopover(initialScreen: .home)
    }

    private func showStatusPopover(initialScreen: CodexAccountMenuView.Screen) {
        guard let button = statusItem?.button else { return }
        window?.orderOut(nil)
        paletteLibraryWindow?.orderOut(nil)
        let requiresActivationPolicyTransition = NSApp.activationPolicy() != .accessory
        NSApp.setActivationPolicy(.accessory)
        if requiresActivationPolicyTransition {
            DispatchQueue.main.async { [weak self] in
                self?.showStatusPopover(initialScreen: initialScreen)
            }
            return
        }
        store.refreshIfStale(maximumAge: 5 * 60)
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentSize = CodexAccountMenuView.preferredSize
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: CodexAccountMenuView(
                store: store,
                settings: settings,
                updateStore: updateStore,
                paletteCatalog: paletteCatalog,
                initialScreen: initialScreen,
                openFullWindow: { [weak self] in
                    self?.openMainWindow(selecting: nil)
                },
                openPaletteLibrary: { [weak self] in
                    self?.openPaletteLibraryWindow()
                },
                quit: {
                    NSApp.terminate(nil)
                }
            )
        )
        statusPopover = popover
        store.setStatusPopoverVisible(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        updateTaskBoardPollingActivity()
        configureStatusPopoverWindow()
        DispatchQueue.main.async { [weak self] in
            self?.configureStatusPopoverWindow()
        }
        installStatusPopoverEventMonitors()
    }

    private func configureStatusPopoverWindow() {
        guard let window = statusPopover?.contentViewController?.view.window else { return }
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle,
        ]
    }

    private func openMainWindow(selecting scope: RuntimeScope?) {
        if let scope {
            store.selectRuntime(scope)
        }
        showMainWindow()
    }

    private var currentPopoverAttention: TaskAttentionItem? {
        store.highestPriorityAttention(
            for: settings.visibleRuntimeScopes,
            updateResult: updateStore.result
        )
    }

    private func openAttentionItem(_ item: TaskAttentionItem) {
        if item.kind == .update {
            updateStore.openPreferredUpdateURL()
            return
        }
        let scope = item.runtimeScope ?? store.selectedRuntimeScope
        if item.threadID != nil {
            store.requestTaskFocus(scope: scope, threadID: item.threadID)
        } else {
            store.selectRuntime(scope)
        }
        showMainWindow()
    }

    private func updateStatusPopoverSize() {
        guard statusPopover?.isShown == true else { return }
        statusPopover?.contentSize = CodexAccountMenuView.preferredSize
    }

    func popoverDidClose(_ notification: Notification) {
        statusPopover = nil
        removeStatusPopoverEventMonitors()
        updateTaskBoardPollingActivity()
        store.setStatusPopoverVisible(false)
    }

    private func closeStatusPopover() {
        statusPopover?.performClose(nil)
        statusPopover = nil
        removeStatusPopoverEventMonitors()
        updateTaskBoardPollingActivity()
        store.setStatusPopoverVisible(false)
    }

    private func updateTaskBoardPollingActivity() {
        guard let window else {
            store.setMainWindowActive(false)
            return
        }
        let mainWindowActive =
            window.isVisible
            && !window.isMiniaturized
            && window.isKeyWindow
            && window.isOnActiveSpace
            && window.occlusionState.contains(.visible)
            && NSApp.isActive
            && !NSApp.isHidden
        store.setMainWindowActive(mainWindowActive)
    }

    private func installStatusPopoverEventMonitors() {
        removeStatusPopoverEventMonitors()
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        if let localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: mouseEvents.union(.keyDown),
            handler: { [weak self] event in
                guard let self else { return event }
                if event.type == .keyDown, event.keyCode == 53 {
                    self.closeStatusPopover()
                    return nil
                }
                if self.shouldCloseStatusPopover(for: event) {
                    self.closeStatusPopover()
                }
                return event
            })
        {
            statusPopoverEventMonitors.append(localMonitor)
        }

        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: mouseEvents,
            handler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.closeStatusPopover()
                }
            })
        {
            statusPopoverEventMonitors.append(globalMonitor)
        }
    }

    private func shouldCloseStatusPopover(for event: NSEvent) -> Bool {
        guard event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .otherMouseDown else {
            return false
        }
        if let popoverWindow = statusPopover?.contentViewController?.view.window, event.window === popoverWindow {
            return false
        }
        if let statusButtonWindow = statusItem?.button?.window, event.window === statusButtonWindow {
            return false
        }
        return true
    }

    private func removeStatusPopoverEventMonitors() {
        for monitor in statusPopoverEventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        statusPopoverEventMonitors.removeAll()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else { return }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        statusItemAppearanceObservation = button.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
            }
        }
        updateStatusItem()
        button.target = self
        button.action = #selector(statusItemClicked)
    }

    private func setupStatusItemIfNeeded() {
        guard statusItem == nil else {
            updateStatusItem()
            return
        }
        setupStatusItem()
    }

    private func observeStatusItemUsage() {
        store.$multiRuntimeSnapshot
            .combineLatest(store.$selectedRuntimeScope, store.$isRefreshing)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updateStatusItem()
                self?.updateStatusPopoverSize()
            }
            .store(in: &cancellables)

        store.$runtimeSnapshots
            .combineLatest(updateStore.$result)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusPopoverSize()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let presentation = currentStatusItemPresentation()
        let appearance = button.effectiveAppearance
        let paletteAppearance: PaletteAppearance = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
        let visualTokens = paletteCatalog.resolve(id: settings.paletteID, appearance: paletteAppearance)

        // Skip redundant redraws. Mutating `button.image`/`length` triggers a
        // status-bar relayout, which re-fires the `effectiveAppearance` KVO
        // observer and calls back into this method. Without this guard the icon
        // repaints in a tight feedback loop, pinning a CPU core.
        if presentation == lastRenderedStatusItemPresentation,
            appearance.name == lastRenderedStatusItemAppearanceName,
            visualTokens.identity == lastRenderedStatusItemPaletteIdentity
        {
            return
        }
        lastRenderedStatusItemPresentation = presentation
        lastRenderedStatusItemAppearanceName = appearance.name
        lastRenderedStatusItemPaletteIdentity = visualTokens.identity

        let performanceSpan = PerformanceMonitor.shared.begin(.statusRender)
        statusItem?.length = presentation.itemLength
        button.image = statusItemRenderer.render(
            presentation,
            tokens: visualTokens,
            appearance: appearance
        )
        button.toolTip = presentation.tooltip
        button.setAccessibilityLabel("Codex Account Manager Next")
        button.setAccessibilityValue(presentation.accessibilityValue)
        PerformanceMonitor.shared.end(performanceSpan)
    }

    private func selectedRuntimeSummary() -> RuntimeMenuSummary? {
        store.runtimeSnapshot(for: store.selectedRuntimeScope)?.summary
    }

    private func currentStatusItemPresentation() -> StatusItemPresentation {
        let source =
            selectedRuntimeSummary().map(StatusItemSourceSnapshot.init(summary:))
            ?? StatusItemSourceSnapshot.unavailable(runtime: store.selectedRuntimeScope)
        return statusItemPresentationBuilder.build(
            source: source,
            preferences: settings.statusItemPreferences,
            language: settings.language,
            shortcutName: settings.globalShortcut?.displayName
        )
    }

    @discardableResult
    private func registerGlobalHotKey(_ shortcut: GlobalShortcut) -> Bool {
        debugLog("register global hotkey \(shortcut.displayName)")
        guard installGlobalHotKeyHandler() else { return false }
        let status = registerHotKeyReference(shortcut, id: 1, reference: &globalHotKeyRef)
        if status == noErr {
            debugLog("global hotkey registered")
        } else {
            debugLog("RegisterEventHotKey failed status=\(status)")
        }
        return status == noErr
    }

    @discardableResult
    private func installGlobalHotKeyHandler() -> Bool {
        guard globalHotKeyHandler == nil else { return true }
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    delegate.toggleMainWindow()
                }
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &globalHotKeyHandler
        )
        guard handlerStatus == noErr else {
            debugLog("InstallEventHandler failed status=\(handlerStatus)")
            return false
        }

        return true
    }

    private func replaceGlobalHotKey(
        with shortcut: GlobalShortcut
    ) -> Result<Void, GlobalShortcutRegistrationFailure> {
        guard installGlobalHotKeyHandler() else { return .failure(.failed) }
        let replacement: Result<EventHotKeyRef, GlobalShortcutRegistrationFailure> =
            GlobalShortcutRegistrationTransaction.replace(
                current: globalHotKeyRef,
                registerCandidate: {
                    var candidateRef: EventHotKeyRef?
                    let status = registerHotKeyReference(
                        shortcut,
                        id: 2,
                        reference: &candidateRef
                    )
                    guard status == noErr, let candidateRef else {
                        debugLog("replacement hotkey registration failed status=\(status)")
                        return .failure(status == eventHotKeyExistsErr ? .occupied : .failed)
                    }
                    return .success(candidateRef)
                },
                unregister: { reference in
                    let status = UnregisterEventHotKey(reference)
                    guard status == noErr else {
                        debugLog("old hotkey unregistration failed status=\(status)")
                        return .failure(.failed)
                    }
                    return .success(())
                },
                rollbackCandidate: { reference in
                    let status = UnregisterEventHotKey(reference)
                    if status != noErr {
                        debugLog("candidate hotkey rollback failed status=\(status)")
                    }
                }
            )
        switch replacement {
        case .failure(let error):
            return .failure(error)
        case .success(let candidateRef):
            globalHotKeyRef = candidateRef
            debugLog("global hotkey replaced with \(shortcut.displayName)")
            return .success(())
        }
    }

    private func registerHotKeyReference(
        _ shortcut: GlobalShortcut,
        id: UInt32,
        reference: inout EventHotKeyRef?
    ) -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: fourCharCode("CAMN"), id: id)
        // Carbon can report conflicts only when the existing registration is
        // also exclusive. macOS does not expose other apps' nonexclusive
        // registrations for preflight inspection.
        return RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            UInt32(kEventHotKeyExclusive),
            &reference
        )
    }

    private func unregisterGlobalHotKey() {
        _ = unregisterGlobalHotKeyReference()
        if let globalHotKeyHandler {
            RemoveEventHandler(globalHotKeyHandler)
        }
        globalHotKeyHandler = nil
    }

    private func unregisterGlobalHotKeyReference() -> Result<Void, GlobalShortcutRegistrationFailure> {
        guard let reference = globalHotKeyRef else { return .success(()) }
        let status = UnregisterEventHotKey(reference)
        guard status == noErr else {
            debugLog("global hotkey unregistration failed status=\(status)")
            return .failure(.failed)
        }
        globalHotKeyRef = nil
        return .success(())
    }
}
