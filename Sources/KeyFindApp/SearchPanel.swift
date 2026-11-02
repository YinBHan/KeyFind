import AppKit
import SwiftUI
import KeyFindCore

final class SearchPanel: NSPanel {
    private let model: SearchPanelViewModel
    private var resignActiveObserver: NSObjectProtocol?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var resignKeyObserver: NSObjectProtocol?

    init(settings: AppSettings) {
        self.model = SearchPanelViewModel(settings: settings)
        super.init(contentRect: NSRect(x: 0, y: 0, width: UIConstants.Panel.width, height: UIConstants.Panel.minimumHeight), styleMask: [.borderless], backing: .buffered, defer: true)
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
        resize(to: NSSize(width: UIConstants.Panel.width, height: UIConstants.Panel.minimumHeight + UIConstants.Panel.discoveryHeight))
        orderOut(nil)
    }

    func positionCentered() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let size = frame.size
        let verticalOffset = UIConstants.Panel.verticalCenterOffset
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

