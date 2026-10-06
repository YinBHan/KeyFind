import AppKit
import Carbon
import KeyFindCore

final class GlobalHotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    var isRegistered: Bool { hotKeyRef != nil }

    static func hotKey(for event: NSEvent) -> GlobalHotKey? {
        guard event.type == .keyDown else { return nil }
        let relevantFlags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let modifiers: UInt32 = [
            (NSEvent.ModifierFlags.command, GlobalHotKeyModifier.command),
            (NSEvent.ModifierFlags.shift, GlobalHotKeyModifier.shift),
            (NSEvent.ModifierFlags.option, GlobalHotKeyModifier.option),
            (NSEvent.ModifierFlags.control, GlobalHotKeyModifier.control)
        ].reduce(into: UInt32(0)) { value, item in
            if relevantFlags.contains(item.0) { value |= item.1 }
        }
        guard modifiers != 0 else { return nil }
        let key = GlobalHotKey.keyName(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers
        )
        return GlobalHotKey(keyCode: UInt32(event.keyCode), modifiers: modifiers, displayName: GlobalHotKey.displayName(modifiers: modifiers, key: key))
    }

    func register(_ hotKey: GlobalHotKey, handler: @escaping () -> Void) -> Bool {
        unregister()
        self.handler = handler

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.id == 1 {
                    DispatchQueue.main.async { manager.handler?() }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard installStatus == noErr else {
            self.handler = nil
            return false
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4B464E44), id: 1)
        let registerStatus = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        handler = nil
    }

    deinit {
        unregister()
    }
}
