import XCTest
@testable import KeyFindCore

final class ShortcutSearchTests: XCTestCase {
    private let catalog = [
        Shortcut(
            id: "screen-full",
            title: "截取整个屏幕",
            description: "将整个屏幕保存为图片文件。",
            category: .common,
            keys: ShortcutKey(modifiers: ["⌘", "⇧"], key: "3", readableText: "⌘ Command + ⇧ Shift + 3"),
            searchTerms: ["截图", "截屏", "全屏"],
            scope: .system,
            appIdentifier: nil,
            sourceURL: "https://support.apple.com/zh-cn/102650",
            caution: nil
        ),
        Shortcut(
            id: "screen-area",
            title: "截取选定区域",
            description: "拖动选择屏幕区域并保存为图片。",
            category: .common,
            keys: ShortcutKey(modifiers: ["⌘", "⇧"], key: "4", readableText: "⌘ Command + ⇧ Shift + 4"),
            searchTerms: ["截图", "截屏", "区域截图"],
            scope: .system,
            appIdentifier: nil,
            sourceURL: "https://support.apple.com/zh-cn/102650",
            caution: nil
        ),
        Shortcut(
            id: "copy",
            title: "复制",
            description: "复制选中的文本、文件或其他内容。",
            category: .common,
            keys: ShortcutKey(modifiers: ["⌘"], key: "C", readableText: "⌘ Command + C"),
            searchTerms: ["拷贝", "copy"],
            scope: .system,
            appIdentifier: nil,
            sourceURL: "https://support.apple.com/zh-cn/102650",
            caution: nil
        )
    ]

    func testExactTitleRanksFirst() {
        let results = ShortcutSearchService(shortcuts: catalog).search("复制")
        XCTAssertEqual(results.first?.id, "copy")
    }

    func testChineseSynonymsMatchTheSameShortcuts() {
        let search = ShortcutSearchService(shortcuts: catalog)
        XCTAssertEqual(search.search("截屏").map(\.id), ["screen-full", "screen-area"])
        XCTAssertEqual(search.search("截图").map(\.id), ["screen-full", "screen-area"])
    }

    func testBundledCatalogSupportsCommonSpokenAliases() throws {
        let shortcuts = try ShortcutCatalog().load()
        let search = ShortcutSearchService(shortcuts: shortcuts)

        XCTAssertEqual(search.search("复制文件").first?.id, "copy")
        XCTAssertEqual(search.search("屏幕录制").first?.id, "screen-toolbar")
        XCTAssertEqual(search.search("程序卡死").first?.id, "force-quit")
        XCTAssertEqual(search.search("锁定屏幕").first?.id, "lock-screen")
        XCTAssertEqual(search.search("Spotlight").first?.id, "apple-53")
        XCTAssertEqual(search.search("emoji").first?.id, "apple-54")
        XCTAssertEqual(search.search("预览文件").first?.id, "apple-56")
        XCTAssertEqual(search.search("最小化窗口").first?.id, "apple-45")
    }

    func testAppPrefixTargetsChromeRegardlessOfPreferredApp() throws {
        let shortcuts = try ShortcutCatalog().load() + ShortcutCatalog().loadChrome()
        let search = ShortcutSearchService(shortcuts: shortcuts)

        XCTAssertEqual(search.search("谷歌 打开新标签页", preferredApp: nil).first?.id, "chrome-new-tab")
        XCTAssertEqual(search.search("Chrome 地址栏", preferredApp: nil).first?.id, "chrome-address-bar")
        XCTAssertEqual(search.search("谷歌 无痕模式", preferredApp: .chrome).first?.id, "chrome-incognito")
    }

    func testAppPrefixDoesNotMixSystemShortcutsIntoAppResults() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())

        let results = search.search("Chrome 复制", limit: 20)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.app == .chrome })
    }

    func testAppOnlyQueryShowsChromeSuggestions() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().load() + ShortcutCatalog().loadChrome())

        let results = search.search("谷歌", limit: 6, preferredApp: nil)

        XCTAssertEqual(results.count, 6)
        XCTAssertTrue(results.allSatisfy { $0.app == .chrome })
        XCTAssertEqual(results.first?.id, "chrome-new-tab")
    }

    func testAvailableSourcesAreDerivedFromCatalog() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().load() + ShortcutCatalog().loadChrome())

        XCTAssertEqual(search.availableSources, [.system, .app(.chrome)])
        XCTAssertEqual(search.shortcuts(in: .app(.chrome), limit: 2).map(\.app), [.chrome, .chrome])
    }

    func testFavoriteShortcutsFilterPreservesCatalogOrderAndLimit() {
        let search = ShortcutSearchService(shortcuts: catalog + [
            Shortcut(
                id: "favorite-extra", title: "收藏的额外操作", description: "测试收藏筛选。", category: .common,
                keys: ShortcutKey(modifiers: ["⌘"], key: "E", readableText: "⌘ + E"),
                searchTerms: ["收藏"], scope: .system, appIdentifier: nil,
                sourceURL: "https://support.apple.com/zh-cn/102650", caution: nil
            )
        ])

        let favorites = search.shortcuts(withIDs: ["favorite-extra", "copy", "missing"], limit: 2)

        XCTAssertEqual(favorites.map(\.id), ["copy", "favorite-extra"])
        XCTAssertEqual(search.count(withIDs: ["favorite-extra", "copy", "missing"]), 2)
    }

    func testSourceFilterOverridesPreferredAppAndKeepsPrefixIntent() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().load() + ShortcutCatalog().loadChrome())

        XCTAssertTrue(search.search("复制", limit: 20, preferredApp: .chrome, source: .system).allSatisfy { $0.scope == .system })
        XCTAssertTrue(search.search("谷歌 打开新标签页", limit: 20, preferredApp: nil, source: .system).allSatisfy { $0.app == .chrome })
    }

    func testFinderPrefixTargetsFinderShortcuts() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())

        XCTAssertEqual(search.search("访达 移动文件", preferredApp: .chrome).first?.id, "finder-finder-move-here")
        XCTAssertTrue(search.search("Finder 新建文件夹", limit: 20).allSatisfy { $0.app == .finder })
    }

    func testFinderOnlyQueryShowsFinderSuggestions() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())

        let results = search.search("访达", limit: 6)

        XCTAssertEqual(results.count, 6)
        XCTAssertTrue(results.allSatisfy { $0.app == .finder })
    }

    func testSafariPrefixAndOnlyQuery() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())
        XCTAssertEqual(search.search("Safari 新开标签", limit: 20).first?.id, "safari-new-tab")
        XCTAssertEqual(search.search("Safari新开标签", limit: 20).first?.id, "safari-new-tab")
        let suggestions = search.search("苹果浏览器", limit: 6)
        XCTAssertEqual(suggestions.count, 6)
        XCTAssertTrue(suggestions.allSatisfy { $0.app == .safari })
    }

    func testVSCodePrefixAndOnlyQuery() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())

        XCTAssertEqual(search.search("VS Code 全局搜索", limit: 20).first?.id, "vscode-search-files")
        let suggestions = search.search("代码编辑器", limit: 6)
        XCTAssertEqual(suggestions.count, 6)
        XCTAssertTrue(suggestions.allSatisfy { $0.app == .vscode })
    }

    func testChatGPTPrefixAndOnlyQuery() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())

        XCTAssertEqual(search.search("ChatGPT 打开", limit: 20).first?.id, "chatgpt-open")
        XCTAssertEqual(search.search("OpenAI ChatGPT", limit: 6).first?.id, "chatgpt-open")
    }

    func testEverydayPhrasesResolveToTheExpectedShortcut() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())

        XCTAssertEqual(search.search("把文件移到文件夹").first?.id, "finder-finder-move-here")
        XCTAssertEqual(search.search("恢复刚关闭的页面").first?.id, "chrome-reopen-tab")
        XCTAssertEqual(search.search("显示访达路径栏").first?.id, "finder-apple-99")
        XCTAssertEqual(search.search("访达 打开下载").first?.id, "finder-apple-88")
        XCTAssertEqual(search.search("谷歌 关闭窗口").first?.id, "chrome-close-window")
    }

    func testCommonMacSearchPhrasesResolveToUsefulResults() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())

        XCTAssertEqual(search.search("打开聚焦").first?.id, "apple-53")
        XCTAssertEqual(search.search("打开表情面板").first?.id, "apple-54")
        XCTAssertEqual(search.search("窗口缩到Dock").first?.id, "apple-45")
        XCTAssertEqual(search.search("强制关闭卡住的程序").first?.id, "force-quit")
        XCTAssertEqual(search.search("文件快速预览").first?.id, "apple-56")
        XCTAssertEqual(search.search("退出软件").first?.id, "apple-48")
    }

    func testCommonBrowserSearchPhrasesResolveWithAppPrefix() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())

        XCTAssertEqual(search.search("谷歌 刷新一下").first?.id, "chrome-reload")
        XCTAssertEqual(search.search("谷歌 恢复关闭的标签").first?.id, "chrome-reopen-tab")
        XCTAssertEqual(search.search("Chrome 搜索网页文字").first?.id, "chrome-find-page")
        XCTAssertEqual(search.search("Safari 私密窗口").first?.id, "safari-private-window")
        XCTAssertEqual(search.search("Safari 下载列表").first?.id, "safari-downloads")
    }

    func testSearchUsesRegistryAliasesForARegisteredApp() {
        let app = ShortcutApp.chrome
        let descriptor = ShortcutSourceDescriptor(
            app: app,
            displayName: "Chrome",
            bundleIdentifier: app.bundleIdentifier,
            searchAliases: ["浏览器别名"],
            sourceURL: URL(string: "https://example.com")!,
            resourceName: "chrome-shortcuts"
        )
        let registry = ShortcutSourceRegistry(descriptors: [descriptor])
        let shortcut = Shortcut(
            id: "test-shortcut", title: "测试操作", description: "测试注册表别名。", category: .common,
            keys: ShortcutKey(modifiers: ["⌘"], key: "K", readableText: "⌘ + K"),
            searchTerms: ["打开测试"], scope: .app, appIdentifier: app.bundleIdentifier,
            sourceURL: "https://example.com", caution: nil
        )

        let search = ShortcutSearchService(shortcuts: [shortcut], sourceRegistry: registry)
        XCTAssertEqual(search.search("浏览器别名 打开测试").first?.id, "test-shortcut")
        XCTAssertEqual(search.search("浏览器别名").first?.id, "test-shortcut")
    }

    func testNormalizationIgnoresCommonSearchPunctuation() {
        XCTAssertEqual(
            ShortcutSearchService.normalize("  屏幕-录制（工具）  "),
            "屏幕录制工具"
        )
    }

    func testPunctuationAndWhitespaceAreIgnored() {
        let results = ShortcutSearchService(shortcuts: catalog).search("  截 图，  ")
        XCTAssertEqual(results.first?.id, "screen-full")
    }

    func testSearchIsLimitedAndDeterministic() {
        let many = (0..<8).map { index in
            Shortcut(
                id: "item-\(index)", title: "操作\(index)", description: "测试操作", category: .common,
                keys: ShortcutKey(modifiers: ["⌘"], key: "\(index)", readableText: "⌘ + \(index)"),
                searchTerms: ["操作"], scope: .system, appIdentifier: nil,
                sourceURL: "https://support.apple.com/zh-cn/102650", caution: nil
            )
        }
        let results = ShortcutSearchService(shortcuts: many).search("操作", limit: 5)
        XCTAssertEqual(results.count, 5)
        XCTAssertEqual(results.map(\.id), ["item-0", "item-1", "item-2", "item-3", "item-4"])
    }

    func testMatchingCountReportsAllResultsBeyondDisplayLimit() {
        let many = (0..<8).map { index in
            Shortcut(
                id: "item-\(index)", title: "操作\(index)", description: "测试操作", category: .common,
                keys: ShortcutKey(modifiers: ["⌘"], key: "\(index)", readableText: "⌘ + \(index)"),
                searchTerms: ["操作"], scope: .system, appIdentifier: nil,
                sourceURL: "https://support.apple.com/zh-cn/102650", caution: nil
            )
        }

        let search = ShortcutSearchService(shortcuts: many)

        XCTAssertEqual(search.matchingCount(for: "操作"), 8)
        XCTAssertEqual(search.matchingCount(for: "不存在"), 0)
    }

    func testCategoryCountReportsAllShortcutsInCategory() {
        let search = ShortcutSearchService(shortcuts: catalog)

        XCTAssertEqual(search.count(in: .common), 3)
        XCTAssertEqual(search.shortcuts(in: .common, limit: 2).count, 2)
    }

    func testBundledCatalogSearchFindsFinderMoveShortcut() throws {
        let shortcuts = try ShortcutCatalog().loadAll()
        let result = try XCTUnwrap(ShortcutSearchService(shortcuts: shortcuts).search("移动文件").first)
        XCTAssertEqual(result.id, "finder-finder-move-here")
        XCTAssertEqual(result.keys.symbolText, "⌥ ⌘ V")
    }

    func testCutSearchDoesNotShowDuplicateFinderMoveShortcut() throws {
        let search = ShortcutSearchService(shortcuts: try ShortcutCatalog().loadAll())
        let moveResults = search.search("剪切", limit: 20).filter { $0.keys.symbolText == "⌥ ⌘ V" }

        XCTAssertEqual(moveResults.map(\.id), ["finder-finder-move-here"])
    }

    func testUnknownQueryReturnsNoResults() {
        XCTAssertTrue(ShortcutSearchService(shortcuts: catalog).search("火星飞船").isEmpty)
    }

    func testCategoryBrowseReturnsOnlyShortcutsInThatCategory() {
        let shortcuts = catalog + [
            Shortcut(
                id: "finder-copy", title: "复制文件", description: "复制所选文件。", category: .finderSystem,
                keys: ShortcutKey(modifiers: ["⌘"], key: "D", readableText: "⌘ Command + D"),
                searchTerms: ["复制文件"], scope: .system, appIdentifier: nil,
                sourceURL: "https://support.apple.com/zh-cn/102650", caution: nil
            )
        ]

        let results = ShortcutSearchService(shortcuts: shortcuts).shortcuts(in: .finderSystem, limit: 6)

        XCTAssertEqual(results.map(\.id), ["finder-copy"])
    }

    func testCategoryBrowseHonorsLimitAndCatalogOrder() {
        let items = (0..<8).map { index in
            Shortcut(
                id: "finder-\(index)", title: "访达操作\(index)", description: "测试操作", category: .finderSystem,
                keys: ShortcutKey(modifiers: ["⌘"], key: "\(index)", readableText: "⌘ + \(index)"),
                searchTerms: ["访达操作\(index)"], scope: .system, appIdentifier: nil,
                sourceURL: "https://support.apple.com/zh-cn/102650", caution: nil
            )
        }

        let results = ShortcutSearchService(shortcuts: items).shortcuts(in: .finderSystem, limit: 5)

        XCTAssertEqual(results.map(\.id), ["finder-0", "finder-1", "finder-2", "finder-3", "finder-4"])
    }
}
