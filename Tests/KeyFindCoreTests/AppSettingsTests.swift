import XCTest
@testable import KeyFindCore

final class AppSettingsTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "KeyFindTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testDefaultsUseCommandShiftSpaceAndPersistChanges() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.globalHotKey, .commandShiftSpace)
        XCTAssertEqual(settings.globalHotKey.keyCode, 49)
        XCTAssertEqual(settings.globalHotKey.modifiers, 0x0300)
        XCTAssertEqual(settings.globalHotKey.displayName, "⌘⇧ Space")

        let custom = GlobalHotKey(keyCode: 36, modifiers: GlobalHotKeyModifier.command, displayName: "⌘ Return")
        settings.setGlobalHotKey(custom)
        XCTAssertEqual(AppSettings(defaults: defaults).globalHotKey, custom)
    }

    func testHotKeyDisplayNameUsesMacModifierOrder() {
        XCTAssertEqual(GlobalHotKeyModifier.command, 0x0100)
        XCTAssertEqual(GlobalHotKeyModifier.shift, 0x0200)
        XCTAssertEqual(GlobalHotKeyModifier.option, 0x0800)
        XCTAssertEqual(GlobalHotKeyModifier.control, 0x1000)
        XCTAssertEqual(GlobalHotKey.displayName(modifiers: 0x1B00, key: "K"), "⌘⇧⌥⌃ K")
        XCTAssertEqual(GlobalHotKey.displayName(modifiers: 0x0100, key: "Return"), "⌘ Return")
        XCTAssertEqual(GlobalHotKey.displayName(modifiers: 0, key: "Space"), "Space")
    }

    func testRecordedHotKeyUsesReadableKeyNames() {
        XCTAssertEqual(GlobalHotKey.keyName(keyCode: 40, charactersIgnoringModifiers: "k"), "K")
        XCTAssertEqual(GlobalHotKey.keyName(keyCode: 126, charactersIgnoringModifiers: ""), "Up")
        XCTAssertEqual(GlobalHotKey.keyName(keyCode: 122, charactersIgnoringModifiers: ""), "F1")
        XCTAssertEqual(GlobalHotKey.keyName(keyCode: 64, charactersIgnoringModifiers: ""), "F17")
    }

    func testFavoritesAndRecentSearchesPersistWithBoundedHistory() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.toggleFavorite(id: "screen-full")
        (0..<12).forEach { settings.recordSearch("查询\($0)") }
        settings.recordSearch("查询11")

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertTrue(reloaded.favoriteIDs.contains("screen-full"))
        XCTAssertEqual(reloaded.recentSearches.count, 10)
        XCTAssertEqual(reloaded.recentSearches.first, "查询11")
        XCTAssertEqual(reloaded.recentSearches.filter { $0 == "查询11" }.count, 1)
    }

    func testMalformedHotKeyFallsBackToDefault() {
        let defaults = makeDefaults()
        defaults.set(Data("bad".utf8), forKey: "globalHotKey")
        XCTAssertEqual(AppSettings(defaults: defaults).globalHotKey, .commandShiftSpace)
    }

    func testLegacyOptionSpaceIsMigratedToCommandShiftSpace() throws {
        let defaults = makeDefaults()
        defaults.set(try JSONEncoder().encode(GlobalHotKey.optionSpace), forKey: "globalHotKey")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.globalHotKey, .commandShiftSpace)
        XCTAssertEqual(AppSettings(defaults: defaults).globalHotKey, .commandShiftSpace)
    }

    func testLegacyControlModifierIsMigratedToCarbonControlFlag() throws {
        let defaults = makeDefaults()
        let legacy = GlobalHotKey(keyCode: 40, modifiers: 0x0500, displayName: "⌘⌃ K")
        defaults.set(try JSONEncoder().encode(legacy), forKey: "globalHotKey")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.globalHotKey.modifiers, GlobalHotKeyModifier.command | GlobalHotKeyModifier.control)
        XCTAssertEqual(settings.globalHotKey.displayName, "⌘⌃ K")
        XCTAssertEqual(AppSettings(defaults: defaults).globalHotKey, settings.globalHotKey)
    }

    func testLaunchAtLoginPreferenceDefaultsOffAndPersists() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        XCTAssertFalse(settings.launchAtLogin)
        settings.setLaunchAtLogin(true)

        XCTAssertTrue(AppSettings(defaults: defaults).launchAtLogin)
    }
}
