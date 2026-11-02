import AppKit
import os.log

enum KeyFindLog {
    static let runtime = Logger(subsystem: "com.keyfind.app", category: "runtime")

    static func debug(_ message: String) {
#if DEBUG
        runtime.debug("\(message, privacy: .public)")
#endif
    }
}

enum StatusBarIcon {
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

