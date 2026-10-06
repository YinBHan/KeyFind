import AppKit
import os.log
import ServiceManagement
import SwiftUI
import KeyFindCore

private enum KeyFindLog {
    static let runtime = Logger(subsystem: "com.keyfind.app", category: "runtime")

    static func debug(_ message: String) {
#if DEBUG
        runtime.debug("\(message, privacy: .public)")
#endif
    }
}

private enum StatusBarIcon {
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()

        let keycap = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 7.2, width: 9.2, height: 6.8), xRadius: 2.2, yRadius: 2.2)
        keycap.lineWidth = 1.7
        NSColor.black.setStroke()
        keycap.stroke()

        let lens = NSBezierPath(ovalIn: NSRect(x: 7.2, y: 3.3, width: 7.4, height: 7.4))
        lens.lineWidth = 1.7
        lens.stroke()

        let handle = NSBezierPath()
        handle.lineWidth = 1.7
        handle.move(to: NSPoint(x: 13.1, y: 4.2))
        handle.line(to: NSPoint(x: 16.2, y: 1.1))
        handle.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var panel: SearchPanel?
    private var statusItem: NSStatusItem?
    private var hotKeyMenuItem: NSMenuItem?
    private var launchAtLoginMenuItem: NSMenuItem?
    private var panelRequestPending = false
    private let hotKeyManager = GlobalHotKeyManager()
    let settings = AppSettings()
    @Published private(set) var launchAtLogin = false
    @Published private(set) var hotKeyStatus = ""

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }

    var preferredApp: ShortcutApp? {
        guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return nil }
        return ShortcutCatalog().sourceRegistry.descriptors.first { $0.bundleIdentifier == bundleIdentifier }?.app
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        launchAtLogin = settings.launchAtLogin || loginItemIsActive
        settings.setLaunchAtLogin(launchAtLogin)
        installStatusItem()
        panel = SearchPanel(settings: settings)
        let registered = hotKeyManager.register(settings.globalHotKey) { [weak self] in
            self?.writeDiagnostic("Global hotkey pressed")
            self?.showPanel()
        }
        writeDiagnostic("KeyFind launched. Global hotkey \(settings.globalHotKey.displayName) registration: \(registered ? "success" : "failed")")
        if !registered {
            DispatchQueue.main.async { [weak self] in
                self?.showHotKeyRegistrationFailure()
            }
        }
    }

    // Menu bar apps do not have a normal document window. macOS calls these
    // delegate methods when the user opens the app from Spotlight, Finder,
    // or the Dock, including when the process is already running.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        requestPanelPresentation(source: "Open")
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        requestPanelPresentation(source: "Reopen visible=\(flag)")
        return true
    }

    private func requestPanelPresentation(source: String) {
        guard !panelRequestPending else {
            writeDiagnostic("Duplicate \(source) request ignored")
            return
        }
        panelRequestPending = true
        writeDiagnostic("\(source) request received")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.panelRequestPending = false
            self.showPanel()
        }
    }

    func toggleLaunchAtLogin() {
        let shouldEnable = !launchAtLogin
        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = shouldEnable
            settings.setLaunchAtLogin(launchAtLogin)
            launchAtLoginMenuItem?.state = shouldEnable ? .on : .off
        } catch {
            writeDiagnostic("Launch at login update failed: \(error.localizedDescription)")
            showLaunchAtLoginFailure(error)
        }
    }

    func showHotKeySettings() {
        let alert = NSAlert()
        alert.messageText = "修改 KeyFind 快捷键"
        alert.informativeText = "直接按下新的组合键。至少需要一个 Command、Shift、Option 或 Control 修饰键。"
        let recorder = HotKeyRecorderView(current: settings.globalHotKey)
        alert.accessoryView = recorder
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn, let hotKey = recorder.recordedHotKey else { return }

        let previous = settings.globalHotKey
        let registered = registerHotKey(hotKey)
        guard registered else {
            let restored = registerHotKey(previous)
            hotKeyStatus = "快捷键注册失败，仍使用 \(previous.displayName)"
            writeDiagnostic("Global hotkey change to \(hotKey.displayName) failed; previous registration restore: \(restored ? "success" : "failed")")
            showHotKeyChangeFailure(requested: hotKey, previous: previous, restored: restored)
            return
        }
        settings.setGlobalHotKey(hotKey)
        hotKeyMenuItem?.title = "快捷键  \(hotKey.displayName)"
        statusItem?.button?.toolTip = "KeyFind（\(hotKey.displayName)）"
        hotKeyStatus = "已切换为 \(hotKey.displayName)"
        writeDiagnostic("Global hotkey changed to \(hotKey.displayName)")
    }

    private func registerHotKey(_ hotKey: GlobalHotKey) -> Bool {
        hotKeyManager.register(hotKey) { [weak self] in
            self?.writeDiagnostic("Global hotkey pressed")
            self?.showPanel()
        }
    }

    func showPanel() {
        guard let panel else {
            writeDiagnostic("Show panel skipped: panel is nil")
            return
        }
        writeDiagnostic("Show panel begin: active=\(NSApp.isActive) visible=\(panel.isVisible) key=\(panel.isKeyWindow) frame=\(NSStringFromRect(panel.frame))")
        panel.prepareForPresentation()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak panel] in
            panel?.refreshLayout()
            guard let panel else { return }
            self.writeDiagnostic("Show panel end: active=\(NSApp.isActive) visible=\(panel.isVisible) key=\(panel.isKeyWindow) frame=\(NSStringFromRect(panel.frame))")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else { return }
        button.image = StatusBarIcon.image()
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "KeyFind（\(settings.globalHotKey.displayName)）"
        item.menu = makeStatusMenu()
        statusItem = item
        writeDiagnostic("Status item installed")
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let openItem = NSMenuItem(title: "打开 KeyFind", action: #selector(openPanelFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let hotKeyItem = NSMenuItem(title: "快捷键  \(settings.globalHotKey.displayName)", action: nil, keyEquivalent: "")
        hotKeyItem.isEnabled = false
        menu.addItem(hotKeyItem)
        hotKeyMenuItem = hotKeyItem

        let editItem = NSMenuItem(title: "修改快捷键…", action: #selector(editHotKeyFromMenu), keyEquivalent: "")
        editItem.target = self
        menu.addItem(editItem)
        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: "开机启动", action: #selector(toggleLaunchAtLoginFromMenu), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = launchAtLogin ? .on : .off
        menu.addItem(launchItem)
        launchAtLoginMenuItem = launchItem

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 KeyFind", action: #selector(quitFromMenu), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    @objc private func openPanelFromMenu() {
        showPanel()
    }

    @objc private func editHotKeyFromMenu() {
        showHotKeySettings()
    }

    @objc private func toggleLaunchAtLoginFromMenu() {
        toggleLaunchAtLogin()
    }

    @objc private func quitFromMenu() {
        NSApplication.shared.terminate(nil)
    }

    private func writeDiagnostic(_ message: String) {
        KeyFindLog.debug(message)
    }

    private func showHotKeyRegistrationFailure() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "快捷键未注册"
        alert.informativeText = "KeyFind 无法注册 \(settings.globalHotKey.displayName)，可能与其他应用冲突。请在菜单栏确认当前快捷键，或退出占用它的应用后重试。"
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private func showLaunchAtLoginFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "无法更新开机启动"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private func showHotKeyChangeFailure(requested: GlobalHotKey, previous: GlobalHotKey, restored: Bool) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "快捷键未更改"
        if restored {
            alert.informativeText = "无法注册 \(requested.displayName)，可能与其他应用冲突。KeyFind 仍使用 \(previous.displayName)。"
        } else {
            alert.informativeText = "无法注册 \(requested.displayName)，且旧快捷键也未能恢复。请重新打开 KeyFind 后再试。"
        }
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private var loginItemIsActive: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        default:
            return false
        }
    }
}

final class SearchPanel: NSPanel {
    private let model: SearchPanelModel
    private var resignActiveObserver: NSObjectProtocol?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var resignKeyObserver: NSObjectProtocol?

    init(settings: AppSettings) {
        self.model = SearchPanelModel(settings: settings)
        super.init(contentRect: NSRect(x: 0, y: 0, width: 560, height: 103), styleMask: [.borderless], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = true
        becomesKeyOnlyIfNeeded = false
        animationBehavior = .utilityWindow
        appearance = nil
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        contentView = NSHostingView(rootView: SearchPanelView(model: model, close: { [weak self] in self?.orderOut(nil) }))
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            KeyFindLog.debug("Panel resigned key; hiding")
            self?.orderOut(nil)
        }
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            KeyFindLog.debug("App resigned active; hiding panel")
            self?.orderOut(nil)
        }
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                application.bundleIdentifier != Bundle.main.bundleIdentifier
            else { return }
            KeyFindLog.debug("Another app activated (\(application.bundleIdentifier ?? "unknown")); hiding panel")
            self?.orderOut(nil)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    deinit {
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
        }
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
    }

    func prepareForPresentation() {
        model.reset()
        resize(to: NSSize(width: 560, height: 103 + 178))
        orderOut(nil)
    }

    func positionCentered() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let size = frame.size
        let verticalOffset: CGFloat = 64
        setFrameOrigin(NSPoint(x: visibleFrame.midX - size.width / 2, y: visibleFrame.midY - size.height / 2 + verticalOffset))
    }

    func resize(to size: NSSize) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let boundedHeight = min(size.height, visibleFrame.height - 40)
        setContentSize(NSSize(width: size.width, height: boundedHeight))
        positionCentered()
    }

    func refreshLayout() {
        (contentView as? NSHostingView<SearchPanelView>)?.rootView.refreshLayout()
    }

}

private final class HotKeyRecorderView: NSView {
    private let label = NSTextField(labelWithString: "")
    private(set) var recordedHotKey: GlobalHotKey?

    init(current: GlobalHotKey) {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 58))
        label.stringValue = current.displayName
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 16, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let hotKey = GlobalHotKeyManager.hotKey(for: event) else {
            NSSound.beep()
            return
        }
        recordedHotKey = hotKey
        label.stringValue = hotKey.displayName
    }
}

@MainActor
final class SearchPanelModel: ObservableObject {
    private let pageSize = 6

    @Published var query = "" {
        didSet {
            if !query.isEmpty {
                browseCategory = nil
                favoritesOnly = false
            }
            displayedLimit = pageSize
            updateResults()
            selectedIndex = min(selectedIndex, max(results.count - 1, 0))
        }
    }
    @Published private(set) var results: [Shortcut] = []
    @Published private(set) var totalResultCount = 0
    @Published private(set) var displayedLimit = 6
    @Published private(set) var catalogError: String?
    @Published var selectedIndex = 0
    @Published private(set) var browseCategory: ShortcutCategory?
    @Published var selectedSource: ShortcutSource?
    @Published var favoritesOnly = false
    @Published var copiedShortcutID: String?

    let settings: AppSettings
    private let catalog: ShortcutCatalog
    private let sourceRegistry: ShortcutSourceRegistry
    private let searchService: ShortcutSearchService
    private var preferredApp: ShortcutApp?

    var availableSources: [ShortcutSource] { searchService.availableSources }

    var requestedApp: ShortcutApp? {
        let normalized = ShortcutSearchService.normalize(query)
        return sourceRegistry.app(forAlias: normalized)
    }

    var requestedAppInfo: ShortcutAppInfo? {
        guard let requestedApp else { return nil }
        return catalog.appSources.first { $0.app == requestedApp }
    }

    var requestedAppCount: Int {
        guard let requestedApp else { return 0 }
        return searchService.count(for: requestedApp)
    }

    init(settings: AppSettings) {
        self.settings = settings
        let catalog = ShortcutCatalog()
        self.catalog = catalog
        let registry = catalog.sourceRegistry
        self.sourceRegistry = registry
        let shortcuts: [Shortcut]
        let catalogError: String?
        do {
            shortcuts = try catalog.loadAll()
            catalogError = nil
        } catch {
            shortcuts = []
            catalogError = error.localizedDescription
        }
        self.catalogError = catalogError
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            .flatMap { identifier in registry.descriptors.first { $0.bundleIdentifier == identifier }?.app }
        preferredApp = app
        searchService = ShortcutSearchService(shortcuts: shortcuts, sourceRegistry: registry)
    }

    var canShowMore: Bool { results.count < totalResultCount }

    var resultSummary: String {
        guard totalResultCount > 0 else { return "" }
        if canShowMore {
            return "显示 \(results.count) / \(totalResultCount) 条"
        }
        return "共 \(totalResultCount) 条"
    }

    var favoriteCount: Int { settings.favoriteIDs.count }

    func reset() {
        preferredApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            .flatMap { identifier in sourceRegistry.descriptors.first { $0.bundleIdentifier == identifier }?.app }
        query = ""
        browseCategory = nil
        selectedSource = nil
        results = []
        totalResultCount = 0
        displayedLimit = pageSize
        selectedIndex = 0
        favoritesOnly = false
        copiedShortcutID = nil
    }

    func selectRecentSearch(_ value: String) {
        browseCategory = nil
        query = value
    }

    func selectSource(_ source: ShortcutSource?) {
        selectedSource = source
        browseCategory = nil
        displayedLimit = pageSize
        updateResults()
        selectedIndex = min(selectedIndex, max(results.count - 1, 0))
    }

    func toggleFavoritesOnly() {
        favoritesOnly.toggle()
        browseCategory = nil
        displayedLimit = pageSize
        updateResults()
        selectedIndex = min(selectedIndex, max(results.count - 1, 0))
    }

    func browse(_ category: ShortcutCategory) {
        browseCategory = category
        query = ""
        displayedLimit = Int.max
        results = searchService.shortcuts(in: category, limit: Int.max)
        totalResultCount = searchService.count(in: category)
        selectedIndex = 0
    }

    func clearBrowse() {
        browseCategory = nil
        results = []
        totalResultCount = 0
        displayedLimit = pageSize
        selectedIndex = 0
    }

    func showMore() {
        guard canShowMore else { return }
        displayedLimit += pageSize
        updateResults()
    }

    func moveSelection(_ direction: MoveCommandDirection) {
        guard !results.isEmpty else { return }
        if direction == .down { selectedIndex = min(selectedIndex + 1, results.count - 1) }
        if direction == .up { selectedIndex = max(selectedIndex - 1, 0) }
    }

    func selectedShortcut() -> Shortcut? { results.indices.contains(selectedIndex) ? results[selectedIndex] : nil }

    func toggleFavorite(_ shortcut: Shortcut) {
        settings.toggleFavorite(id: shortcut.id)
        if favoritesOnly {
            updateResults()
            selectedIndex = min(selectedIndex, max(results.count - 1, 0))
        }
        objectWillChange.send()
    }

    func copy(_ shortcut: Shortcut) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(shortcut.keys.readableText, forType: .string)
        settings.recordSearch(query)
        copiedShortcutID = shortcut.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard self?.copiedShortcutID == shortcut.id else { return }
            self?.copiedShortcutID = nil
        }
    }

    private func updateResults() {
        if let category = browseCategory {
            let limit = displayedLimit == Int.max ? Int.max : displayedLimit
            results = searchService.shortcuts(in: category, limit: limit)
            totalResultCount = searchService.count(in: category)
        } else {
            if favoritesOnly {
                results = searchService.shortcuts(withIDs: settings.favoriteIDs, limit: displayedLimit, source: selectedSource)
                totalResultCount = searchService.count(withIDs: settings.favoriteIDs, source: selectedSource)
            } else {
                results = searchService.search(query, limit: displayedLimit, preferredApp: preferredApp, source: selectedSource)
                totalResultCount = searchService.matchingCount(for: query, preferredApp: preferredApp, source: selectedSource)
            }
            if !favoritesOnly, results.isEmpty, let requestedApp = sourceRegistry.app(forAlias: query) {
                let requestedSource = ShortcutSource.app(requestedApp)
                if selectedSource == nil || selectedSource == requestedSource {
                    results = searchService.appSuggestions(for: requestedApp, limit: displayedLimit)
                    totalResultCount = searchService.appSuggestions(for: requestedApp, limit: Int.max).count
                }
            }
        }
    }
}

struct SearchPanelView: View {
    @ObservedObject var model: SearchPanelModel
    @FocusState private var isSearchFocused: Bool
    private let close: () -> Void

    init(model: SearchPanelModel, close: @escaping () -> Void) {
        self.model = model
        self.close = close
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                TextField("搜索快捷键…", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($isSearchFocused)
                    .onSubmit { if let shortcut = model.selectedShortcut() { model.copy(shortcut) } }
                Text(model.settings.globalHotKey.displayName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 19)
            .frame(height: 72)
            Divider().opacity(0.55)

            if model.query.isEmpty && model.browseCategory == nil && !model.favoritesOnly {
                HStack(spacing: 8) {
                    Button {
                        model.toggleFavoritesOnly()
                    } label: {
                        Label("收藏", systemImage: model.favoritesOnly ? "star.fill" : "star")
                            .font(.system(size: 10, weight: model.favoritesOnly ? .semibold : .regular))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.favoritesOnly ? Color.orange : Color.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(model.favoritesOnly ? Color.orange.opacity(0.12) : Color.primary.opacity(0.06), in: Capsule())
                    Text(model.favoriteCount > 0 ? "已收藏 \(model.favoriteCount) 条" : "还没有收藏")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            if model.query.isEmpty && model.browseCategory == nil && !model.favoritesOnly {
                DiscoveryView(
                    recentSearches: model.settings.recentSearches,
                    onRecentSearch: model.selectRecentSearch,
                    onCategory: model.browse
                )
            } else {
                if model.favoritesOnly {
                    HStack {
                        Text("收藏的快捷键")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Button("返回") { model.toggleFavoritesOnly() }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                if let category = model.browseCategory {
                    HStack(spacing: 8) {
                        Button {
                            model.clearBrowse()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("返回")
                        Text(category.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("共 \(model.totalResultCount) 条")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                if model.browseCategory == nil && !model.results.isEmpty && model.availableSources.count > 1 {
                    SourceFilterView(
                        sources: model.availableSources,
                        selectedSource: model.selectedSource,
                        onSelect: model.selectSource
                    )
                    .padding(.top, 9)
                }
                if !model.results.isEmpty {
                    HStack {
                        Text(model.resultSummary)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, model.requestedApp == nil ? (model.browseCategory == nil ? 10 : 4) : 7)
                }
                Divider().opacity(0.55)
                if model.results.isEmpty {
                    VStack(spacing: 6) {
                        Text(model.catalogError.map { _ in "快捷键数据加载失败" } ?? (model.favoritesOnly ? "还没有收藏的快捷键" : "没有找到匹配的快捷键"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        if let catalogError = model.catalogError {
                            Text(catalogError)
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                        }
                        if let info = model.requestedAppInfo {
                            Text("\(info.displayName) · \(model.requestedAppCount) 个快捷键")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Link("查看官方快捷键 ↗", destination: info.sourceURL)
                                .font(.system(size: 10))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 2) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, shortcut in
                                ShortcutRow(
                                    shortcut: shortcut,
                                    selected: index == model.selectedIndex,
                                    favorite: model.settings.favoriteIDs.contains(shortcut.id),
                                    copied: model.copiedShortcutID == shortcut.id,
                                    onCopy: { model.copy(shortcut) },
                                    onFavorite: { model.toggleFavorite(shortcut) }
                                )
                                    .onHover { if $0 { model.selectedIndex = index } }
                            }
                            if model.canShowMore {
                                Button {
                                    model.showMore()
                                } label: {
                                    Label("显示更多快捷键", systemImage: "chevron.down")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(MoreResultsButtonStyle())
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .frame(height: resultsViewportHeight)
                    Divider().opacity(0.55)
                    HStack {
                        Text("↑ ↓ 选择   ↵ 复制   esc 关闭")
                        Spacer()
                        Link("官方来源 ↗", destination: model.selectedShortcut().flatMap { URL(string: $0.sourceURL) } ?? URL(string: "https://support.apple.com/zh-cn/102650")!)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
            }
        }
        .frame(width: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.primary.opacity(0.12)))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onAppear {
            isSearchFocused = true
            resizePanel()
        }
        .onChange(of: model.query) { _ in
            resizePanel()
        }
        .onChange(of: model.browseCategory) { _ in
            resizePanel()
        }
        .onChange(of: model.selectedSource) { _ in
            resizePanel()
        }
        .onChange(of: model.favoritesOnly) { _ in
            resizePanel()
        }
        .onChange(of: model.displayedLimit) { _ in
            resizePanel()
        }
        .onExitCommand(perform: close)
        .onMoveCommand { model.moveSelection($0) }
    }

    func refreshLayout() {
        DispatchQueue.main.async {
            self.resizePanel()
        }
    }

    private func resizePanel() {
        DispatchQueue.main.async {
            guard let panel = NSApp.windows.first(where: { $0 is SearchPanel }) as? SearchPanel else { return }
            let resultHeight = resultsViewportHeight
            let extraHeight: CGFloat
            if model.query.isEmpty && model.browseCategory == nil && !model.favoritesOnly {
                extraHeight = 72 + 178 + 44
            } else {
                let headingHeight: CGFloat = model.favoritesOnly || model.browseCategory != nil ? 30 : 0
                let sourceHeight: CGFloat = model.browseCategory == nil && !model.results.isEmpty && model.availableSources.count > 1 ? 36 : 0
                let summaryHeight: CGFloat = model.results.isEmpty ? 0 : 24
                let footerHeight: CGFloat = model.results.isEmpty ? 0 : 38
                let emptyStateHeight: CGFloat = model.results.isEmpty ? 74 : 0
                extraHeight = 72 + headingHeight + sourceHeight + summaryHeight + footerHeight + emptyStateHeight + resultHeight
            }
            panel.resize(to: NSSize(width: 560, height: extraHeight))
        }
    }

    private var resultsViewportHeight: CGFloat {
        let rowHeight: CGFloat = 58
        let listPadding: CGFloat = 16
        let moreButtonHeight: CGFloat = model.canShowMore ? 48 : 0
        return min(430, CGFloat(model.results.count) * rowHeight + moreButtonHeight + listPadding)
    }
}

private struct SourceFilterView: View {
    let sources: [ShortcutSource]
    let selectedSource: ShortcutSource?
    let onSelect: (ShortcutSource?) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("来源")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            SourceFilterChip(title: "全部", icon: "square.grid.2x2", selected: selectedSource == nil) {
                onSelect(nil)
            }
            ForEach(sources, id: \.self) { source in
                SourceFilterChip(title: source.displayName, icon: sourceIcon(for: source), selected: selectedSource == source) {
                    onSelect(source)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private func sourceIcon(for source: ShortcutSource) -> String {
        switch source {
        case .system: return "apple.logo"
        case .app(.finder): return "folder"
        case .app(.safari): return "safari"
        case .app(.chrome): return "globe"
        case .app(.vscode): return "chevron.left.forwardslash.chevron.right"
        case .app(.chatgpt): return "bubble.left.and.bubble.right"
        }
    }
}

private struct SourceFilterChip: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: selected ? .semibold : .regular))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.055), in: Capsule())
        .overlay(Capsule().stroke(selected ? Color.accentColor.opacity(0.24) : Color.primary.opacity(0.07)))
    }
}

private struct AppOverviewView: View {
    let app: ShortcutApp
    let info: ShortcutAppInfo
    let shortcutCount: Int

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: app == .finder ? "folder.fill" : app == .safari ? "safari" : "globe")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(app == .finder ? Color.accentColor : app == .safari ? Color.orange : Color.green)
                .frame(width: 28, height: 28)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.system(size: 11, weight: .semibold))
                Text("\(shortcutCount) 个快捷键")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Link(destination: info.sourceURL) {
                Label("官方来源", systemImage: "arrow.up.right")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct DiscoveryView: View {
    let recentSearches: [String]
    let onRecentSearch: (String) -> Void
    let onCategory: (ShortcutCategory) -> Void

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近搜索")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(Array(recentSearches.prefix(3)), id: \.self) { value in
                            Button { onRecentSearch(value) } label: {
                                Label(value, systemImage: "clock")
                                    .lineLimit(1)
                            }
                            .buttonStyle(DiscoveryChipStyle())
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("浏览分类")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(ShortcutCategory.allCases, id: \.self) { category in
                        Button { onCategory(category) } label: {
                            HStack(spacing: 7) {
                                Image(systemName: category.symbolName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(category.symbolColor)
                                    .frame(width: 18, height: 18)
                                    .background(category.symbolColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                                Text(category.rawValue)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(DiscoveryCategoryStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct DiscoveryChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10))
            .foregroundStyle(.primary.opacity(0.78))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.07), in: Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct DiscoveryCategoryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(configuration.isPressed ? 0.16 : 0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.06)))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct MoreResultsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .padding(.vertical, 7)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.accentColor.opacity(0.13)))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private extension ShortcutCategory {
    var symbolName: String {
        switch self {
        case .common: return "command.square"
        case .sleepSystem: return "power"
        case .finderSystem: return "folder"
        case .textEditing: return "character.cursor.ibeam"
        case .accessibility: return "accessibility"
        case .otherAccessibility: return "figure.wave"
        }
    }

    var symbolColor: Color {
        switch self {
        case .common: return .accentColor
        case .sleepSystem: return .orange
        case .finderSystem: return .secondary
        case .textEditing: return .blue
        case .accessibility, .otherAccessibility: return .secondary
        }
    }
}

private extension Shortcut {
    var rowSymbolName: String {
        switch id {
        case "screen-full": return "photo"
        case "screen-area": return "rectangle.dashed"
        case "screen-toolbar": return "rectangle.inset.filled"
        case "copy": return "square.on.square"
        case "cut", "apple-171": return "scissors"
        case "paste", "apple-210": return "doc.on.clipboard"
        case "undo": return "arrow.uturn.backward"
        case "redo": return "arrow.uturn.forward"
        case "find", "apple-43": return "magnifyingglass"
        case "finder-move-here": return "folder.badge.arrow.right"
        case "force-quit": return "xmark.circle"
        case "apple-60", "apple-61", "apple-89": return "folder.badge.plus"
        case "apple-70", "apple-72": return "power"
        case "apple-104": return "link"
        case "apple-110", "apple-111": return "eye"
        case "apple-124", "apple-125": return "trash"
        case "voiceover": return "accessibility"
        case "invert-colors": return "circle.lefthalf.filled"
        default:
            if caution != nil { return "exclamationmark.triangle" }
            switch category {
            case .common: return "command.square"
            case .sleepSystem: return "power"
            case .finderSystem: return "folder"
            case .textEditing: return "textformat"
            case .accessibility, .otherAccessibility: return "accessibility"
            }
        }
    }

    var rowSymbolColor: Color {
        if caution != nil { return .orange }
        switch category {
        case .common: return .accentColor
        case .sleepSystem: return .orange
        case .finderSystem: return .secondary
        case .textEditing: return .secondary
        case .accessibility, .otherAccessibility: return .secondary
        }
    }
}

struct ShortcutRow: View {
    let shortcut: Shortcut
    let selected: Bool
    let favorite: Bool
    let copied: Bool
    let onCopy: () -> Void
    let onFavorite: () -> Void
    @State private var expanded = false

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: shortcut.rowSymbolName)
                .frame(width: 31, height: 31)
                .foregroundStyle(shortcut.rowSymbolColor)
                .background(.quaternary.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(shortcut.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        Text(shortcut.source.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
                Text(shortcut.caution ?? shortcut.description)
                    .font(.system(size: 10))
                    .foregroundStyle(shortcut.caution == nil ? Color.secondary : Color.orange)
                    .lineLimit(expanded ? nil : 1)
                if expanded, let steps = shortcut.steps, !steps.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 6)
            HStack(spacing: 3) {
                ForEach(shortcut.keys.modifiers + (shortcut.keys.key.isEmpty ? [] : [shortcut.keys.key]), id: \.self) { key in
                    Text(key).font(.system(size: 11, weight: .semibold, design: .monospaced)).frame(minWidth: 20).padding(.horizontal, 4).padding(.vertical, 4).background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary))
                }
            }
            Button(action: onFavorite) { Image(systemName: favorite ? "star.fill" : "star").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(favorite ? .orange : .secondary).help("收藏").opacity(selected ? 1 : 0.4)
            Button(action: onCopy) { Image(systemName: copied ? "checkmark" : "doc.on.clipboard").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("复制快捷键")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(selected ? Color.accentColor.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .onTapGesture {
            if shortcut.steps?.isEmpty == false {
                expanded.toggle()
            } else {
                onCopy()
            }
        }
    }
}
