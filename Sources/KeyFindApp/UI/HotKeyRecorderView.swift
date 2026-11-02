import AppKit
import KeyFindCore

final class HotKeyRecorderView: NSView {
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

