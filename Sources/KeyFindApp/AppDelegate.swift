import AppKit
import Combine
import ServiceManagement
import KeyFindCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var panel: SearchPanel?
    var statusItem: NSStatusItem?
    var hotKeyMenuItem: NSMenuItem?
    var launchAtLoginMenuItem: NSMenuItem?
    private var panelRequestPending = false
    private let hotKeyManager = GlobalHotKeyManager()
    let settings = AppSettings()
    @Published var launchAtLogin = false
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
}
