import AppKit
import ServiceManagement
import KeyFindCore

extension AppDelegate {
    func installStatusItem() {
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

    func writeDiagnostic(_ message: String) {
        KeyFindLog.debug(message)
    }

    func showHotKeyRegistrationFailure() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "快捷键未注册"
        alert.informativeText = "KeyFind 无法注册 \(settings.globalHotKey.displayName)，可能与其他应用冲突。请在菜单栏确认当前快捷键，或退出占用它的应用后重试。"
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    func showLaunchAtLoginFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "无法更新开机启动"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    func showHotKeyChangeFailure(requested: GlobalHotKey, previous: GlobalHotKey, restored: Bool) {
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

    var loginItemIsActive: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        default:
            return false
        }
    }
}
