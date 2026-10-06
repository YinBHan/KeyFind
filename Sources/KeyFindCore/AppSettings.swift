import Foundation

public enum GlobalHotKeyModifier {
    public static let command: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000
}

public struct GlobalHotKey: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let displayName: String

    public init(keyCode: UInt32, modifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName
    }

    public static func displayName(modifiers: UInt32, key: String) -> String {
        let symbols: [(UInt32, String)] = [
            (GlobalHotKeyModifier.command, "⌘"),
            (GlobalHotKeyModifier.shift, "⇧"),
            (GlobalHotKeyModifier.option, "⌥"),
            (GlobalHotKeyModifier.control, "⌃")
        ]
        let prefix = symbols
            .filter { modifiers & $0.0 != 0 }
            .map(\.1)
            .joined()
        return prefix.isEmpty ? key : "\(prefix) \(key)"
    }

    public static func keyName(keyCode: UInt16, charactersIgnoringModifiers: String? = nil) -> String {
        let specialKeys: [UInt16: String] = [
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
            71: "Clear", 114: "Help", 115: "Home", 116: "Page Up", 117: "Forward Delete",
            64: "F17", 79: "F18", 80: "F19", 90: "F20", 118: "F4", 119: "End",
            120: "F2", 121: "Page Down", 122: "F1",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12",
            113: "F15", 123: "Left", 124: "Right", 125: "Down", 126: "Up",
            65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 75: "Keypad /",
            76: "Keypad Enter", 78: "Keypad -", 81: "Keypad ="
        ]
        if let specialKey = specialKeys[keyCode] {
            return specialKey
        }

        let characters = charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if characters.count == 1, let scalar = characters.unicodeScalars.first, scalar.value >= 0x20 {
            return characters.uppercased()
        }
        return "Key \(keyCode)"
    }

    /// The current invocation shortcut. Command-Shift-Space avoids the Alt-Space
    /// shortcut reserved by Codex and remains easy to press with one hand.
    public static let commandShiftSpace = GlobalHotKey(
        keyCode: 49,
        modifiers: GlobalHotKeyModifier.command | GlobalHotKeyModifier.shift,
        displayName: "⌘⇧ Space"
    )

    /// Kept to recognize settings written by versions that used Option-Space.
    public static let optionSpace = GlobalHotKey(
        keyCode: 49,
        modifiers: GlobalHotKeyModifier.option,
        displayName: "⌥ Space"
    )
}

public final class AppSettings: @unchecked Sendable {
    private static let legacyIncorrectControlFlag: UInt32 = 0x0400
    private let defaults: UserDefaults
    private let hotKeyKey = "globalHotKey"
    private let launchAtLoginKey = "launchAtLogin"
    private let favoritesKey = "favoriteIDs"
    private let recentSearchesKey = "recentSearches"

    public private(set) var globalHotKey: GlobalHotKey
    public private(set) var launchAtLogin: Bool
    public private(set) var favoriteIDs: Set<String>
    public private(set) var recentSearches: [String]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: hotKeyKey), let stored = try? JSONDecoder().decode(GlobalHotKey.self, from: data) {
            if stored == .optionSpace {
                self.globalHotKey = .commandShiftSpace
                defaults.set(try? JSONEncoder().encode(GlobalHotKey.commandShiftSpace), forKey: hotKeyKey)
            } else if stored.modifiers & Self.legacyIncorrectControlFlag != 0 {
                let migrated = GlobalHotKey(
                    keyCode: stored.keyCode,
                    modifiers: (stored.modifiers & ~Self.legacyIncorrectControlFlag) | GlobalHotKeyModifier.control,
                    displayName: stored.displayName
                )
                self.globalHotKey = migrated
                defaults.set(try? JSONEncoder().encode(migrated), forKey: hotKeyKey)
            } else {
                self.globalHotKey = stored
            }
        } else {
            self.globalHotKey = .commandShiftSpace
        }
        self.launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
        self.favoriteIDs = Set(defaults.stringArray(forKey: favoritesKey) ?? [])
        self.recentSearches = defaults.stringArray(forKey: recentSearchesKey) ?? []
    }

    public func setGlobalHotKey(_ hotKey: GlobalHotKey) {
        globalHotKey = hotKey
        defaults.set(try? JSONEncoder().encode(hotKey), forKey: hotKeyKey)
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        defaults.set(enabled, forKey: launchAtLoginKey)
    }

    public func toggleFavorite(id: String) {
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
        } else {
            favoriteIDs.insert(id)
        }
        defaults.set(Array(favoriteIDs).sorted(), forKey: favoritesKey)
    }

    public func recordSearch(_ query: String) {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        recentSearches.insert(value, at: 0)
        recentSearches = Array(recentSearches.prefix(10))
        defaults.set(recentSearches, forKey: recentSearchesKey)
    }

    public func resetToDefaults() {
        globalHotKey = .commandShiftSpace
        launchAtLogin = false
        favoriteIDs = []
        recentSearches = []
        defaults.removeObject(forKey: hotKeyKey)
        defaults.removeObject(forKey: launchAtLoginKey)
        defaults.removeObject(forKey: favoritesKey)
        defaults.removeObject(forKey: recentSearchesKey)
    }
}
