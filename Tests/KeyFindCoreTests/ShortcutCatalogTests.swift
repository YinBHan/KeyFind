import XCTest
@testable import KeyFindCore

final class ShortcutCatalogTests: XCTestCase {
    func testBundledCatalogLoadsSystemShortcuts() throws {
        let shortcuts = try ShortcutCatalog().load()
        XCTAssertGreaterThanOrEqual(shortcuts.count, 100)
        XCTAssertTrue(shortcuts.allSatisfy { $0.scope == .system })
        XCTAssertTrue(shortcuts.contains { $0.searchTerms.contains("截图") })
        XCTAssertTrue(shortcuts.contains { $0.title == "复制" })
        XCTAssertTrue(shortcuts.contains { $0.searchTerms.contains("放大文字") })
        XCTAssertTrue(shortcuts.contains { $0.id == "apple-41" && $0.keys.symbolText == "⌘ A" })
        XCTAssertTrue(shortcuts.contains { $0.id == "apple-158" && $0.keys.symbolText == "⌘ B" })
    }

    func testAppSourcesExposeMetadataAndUnifiedLoading() throws {
        let catalog = ShortcutCatalog()
        XCTAssertEqual(catalog.appSources.map(\.app), [.chrome, .finder, .safari, .vscode, .chatgpt])
        XCTAssertEqual(catalog.appSources.first?.displayName, "Google Chrome")
        XCTAssertEqual(catalog.appSources.first?.bundleIdentifier, "com.google.Chrome")
        XCTAssertTrue(catalog.appSources.first?.searchAliases.contains("谷歌") == true)
        let chrome = try catalog.load(.chrome)
        let chromeLegacy = try catalog.loadChrome()
        let system = try catalog.load()
        let finder = try catalog.load(.finder)
        let safari = try catalog.load(.safari)
        let vscode = try catalog.loadVSCode()
        let chatgpt = try catalog.loadChatGPT()
        let all = try catalog.loadAll()
        XCTAssertEqual(chrome.count, chromeLegacy.count)
        XCTAssertGreaterThan(finder.count, 40)
        XCTAssertTrue(finder.allSatisfy { $0.app == .finder })
        XCTAssertGreaterThanOrEqual(safari.count, 8)
        XCTAssertTrue(safari.allSatisfy { $0.app == .safari })
        XCTAssertEqual(vscode.count, 8)
        XCTAssertTrue(vscode.allSatisfy { $0.app == .vscode })
        XCTAssertEqual(chatgpt.count, 1)
        XCTAssertTrue(chatgpt.allSatisfy { $0.app == .chatgpt })
        XCTAssertEqual(all.count, system.count + chrome.count + finder.count + safari.count + vscode.count + chatgpt.count)
    }

    func testSourceRegistryResolvesAliasesInStableOrder() throws {
        let registry = ShortcutSourceRegistry.default

        XCTAssertEqual(registry.descriptors.map(\.app), [.chrome, .finder, .safari, .vscode, .chatgpt])
        XCTAssertEqual(registry.app(forAlias: "谷歌浏览器"), .chrome)
        XCTAssertEqual(registry.app(forAlias: "Finder"), .finder)
        XCTAssertEqual(registry.app(forAlias: "苹果浏览器"), .safari)
        XCTAssertEqual(registry.app(forAlias: "代码编辑器"), .vscode)
        XCTAssertEqual(registry.app(forAlias: "OpenAI ChatGPT"), .chatgpt)
        XCTAssertNil(registry.app(forAlias: "未知应用"))
        try registry.validate()
    }

    func testSourceRegistryRejectsDuplicateAliases() {
        let duplicate = ShortcutSourceDescriptor(
            app: .chrome,
            displayName: "Chrome",
            bundleIdentifier: ShortcutApp.chrome.bundleIdentifier,
            searchAliases: ["重复"],
            sourceURL: URL(string: "https://example.com")!,
            resourceName: "chrome-shortcuts"
        )
        let other = ShortcutSourceDescriptor(
            app: .finder,
            displayName: "Finder",
            bundleIdentifier: ShortcutApp.finder.bundleIdentifier,
            searchAliases: ["重复"],
            sourceURL: URL(string: "https://example.com")!,
            resourceName: "finder-shortcuts"
        )

        XCTAssertThrowsError(try ShortcutSourceRegistry(descriptors: [duplicate, other]).validate()) { error in
            XCTAssertEqual(error as? ShortcutCatalogError, .duplicateAliases(["重复"]))
        }
    }

    func testSourceRegistryRejectsIncompleteDescriptorMetadata() {
        let descriptor = ShortcutSourceDescriptor(
            app: .chrome,
            displayName: " ",
            bundleIdentifier: ShortcutApp.chrome.bundleIdentifier,
            searchAliases: ["Chrome"],
            sourceURL: URL(string: "https://example.com")!,
            resourceName: "chrome-shortcuts"
        )

        XCTAssertThrowsError(try ShortcutSourceRegistry(descriptors: [descriptor]).validate()) { error in
            XCTAssertEqual(error as? ShortcutCatalogError, .invalidData("应用快捷键来源缺少显示名称。"))
        }
    }

    func testSourceRegistryRejectsEmptyAlias() {
        let descriptor = ShortcutSourceDescriptor(
            app: .chrome,
            displayName: "Chrome",
            bundleIdentifier: ShortcutApp.chrome.bundleIdentifier,
            searchAliases: ["   "],
            sourceURL: URL(string: "https://example.com")!,
            resourceName: "chrome-shortcuts"
        )

        XCTAssertThrowsError(try ShortcutSourceRegistry(descriptors: [descriptor]).validate()) { error in
            XCTAssertEqual(error as? ShortcutCatalogError, .invalidData("应用快捷键来源包含空别名。"))
        }
    }

    func testBundledCatalogIncludesFinderMoveShortcut() throws {
        let shortcuts = try ShortcutCatalog().loadFinder()

        let move = try XCTUnwrap(shortcuts.first { $0.id == "finder-finder-move-here" })
        XCTAssertEqual(move.title, "将项目移动到此处")
        XCTAssertEqual(move.keys.symbolText, "⌥ ⌘ V")
        XCTAssertTrue(move.searchTerms.contains("移动文件"))
        XCTAssertTrue(move.description.contains("原始位置"))
        XCTAssertEqual(move.steps, ["选中文件", "按 ⌘C", "打开目标文件夹", "按 ⌥⌘V"])
    }

    func testSystemAndFinderCatalogsHaveNoDuplicateShortcuts() throws {
        let catalog = ShortcutCatalog()
        let system = try catalog.load()
        let finder = try catalog.loadFinder()

        let finderSignatures = Set(finder.map { "\($0.title)|\($0.keys.symbolText)|\($0.description)" })
        let duplicateSystemShortcuts = system.filter {
            finderSignatures.contains("\($0.title)|\($0.keys.symbolText)|\($0.description)")
        }

        XCTAssertTrue(duplicateSystemShortcuts.isEmpty, "macOS 目录不应重复包含访达快捷键：\(duplicateSystemShortcuts.map(\.id))")
        XCTAssertTrue(system.allSatisfy { $0.id != "finder-move-here" })
        XCTAssertTrue(finder.contains { $0.id == "finder-finder-move-here" })
    }

    func testAllBundledSourcesHaveUniqueShortcutIDs() throws {
        let shortcuts = try ShortcutCatalog().loadAll()
        let counts = Dictionary(grouping: shortcuts, by: \.id).mapValues(\.count)
        XCTAssertTrue(counts.values.allSatisfy { $0 == 1 })
    }

    func testEveryShortcutHasReadableDescriptionAndSearchTerms() throws {
        let shortcuts = try ShortcutCatalog().load()

        XCTAssertTrue(shortcuts.allSatisfy { !$0.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertTrue(shortcuts.allSatisfy { !$0.searchTerms.isEmpty })
        XCTAssertTrue(shortcuts.allSatisfy { $0.searchTerms.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } })
    }

    func testBundledCatalogHasCleanedOfficialTextArtifacts() throws {
        let shortcuts = try ShortcutCatalog().load()
        let byID = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.id, $0) })

        XCTAssertEqual(byID["apple-153"]?.title, "在 macOS 27 Golden Gate 或更高版本中，如果 Siri AI (Beta) 已打开，可向 Siri 询问有关所选区域的信息")
        XCTAssertEqual(byID["apple-154"]?.title, "在 macOS 27 Golden Gate 或更高版本中，如果 Siri AI (Beta) 已打开，可向 Siri 询问有关当前窗口的信息")
        XCTAssertEqual(byID["apple-155"]?.description, "如果你使用多个输入源以便用不同的语言键入内容，这些快捷键用于选择上一个或下一个输入源。")
        XCTAssertEqual(byID["apple-165"]?.keys.symbolText, "⇧ ⌘ :")
        XCTAssertEqual(byID["apple-214"]?.keys.symbolText, "⇧ ⌘ -")
        XCTAssertFalse(shortcuts.contains { $0.title.hasSuffix(".") || $0.description.contains(".。") })
    }

    func testFinderFolderShortcutsExplainTheirWorkflow() throws {
        let shortcuts = try ShortcutCatalog().loadFinder()
        let newFolder = try XCTUnwrap(shortcuts.first { $0.id == "finder-apple-89" })

        XCTAssertEqual(newFolder.steps, ["打开目标位置", "按 ⇧⌘N", "输入文件夹名称并按回车"])
    }

    func testComplexShortcutsExplainTheRequiredSequence() throws {
        let shortcuts = try ShortcutCatalog().loadAll()
        let byID = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.id, $0) })

        XCTAssertEqual(byID["screen-area"]?.steps, [
            "按 ⌘⇧4", "拖动选择区域", "松开鼠标或触控板"
        ])
        XCTAssertEqual(byID["screen-toolbar"]?.steps, [
            "按 ⌘⇧5", "选择截图或录屏", "按选项设置计时（可选）"
        ])
        XCTAssertEqual(byID["apple-61"]?.steps, [
            "选中要归入文件夹的项目", "按 ⌃⌘N", "输入文件夹名称并按回车"
        ])
        XCTAssertEqual(byID["finder-apple-125"]?.steps, [
            "打开废纸篓并确认内容", "按 ⌥⇧⌘Delete", "直接清倒，不显示确认对话框"
        ])
        XCTAssertEqual(byID["apple-171"]?.steps, [
            "选中文本或将插入点放在段落中", "按 ⌃K", "在同一 App 中按 ⌃Y 粘贴"
        ])
        XCTAssertEqual(byID["force-quit"]?.steps, [
            "按 ⌥⌘Esc", "选中无响应的 App", "按回车强制退出"
        ])
        XCTAssertEqual(byID["apple-60"]?.steps, [
            "打开目标位置", "按 ⇧⌘N", "输入文件夹名称并按回车"
        ])
        XCTAssertEqual(byID["finder-apple-124"]?.steps, [
            "打开废纸篓并确认内容", "按 ⇧⌘Delete", "在确认对话框中点击清倒"
        ])
        XCTAssertEqual(byID["apple-70"]?.steps, [
            "按 ⌃Power", "选择重新启动、睡眠或关机", "确认系统操作"
        ])
        XCTAssertEqual(byID["apple-72"]?.steps, [
            "按 ⌃⌥⌘Power", "按提示处理未保存的文稿", "Mac 退出 App 后关机"
        ])
        XCTAssertEqual(byID["apple-152"]?.steps, [
            "连续按两次 ⌘", "切换‘通过键入使用 Siri’"
        ])
        XCTAssertEqual(byID["apple-163"]?.steps, [
            "打开或存储对话框", "按 ⌘D", "选择桌面文件夹"
        ])
        for id in ["apple-190", "apple-191", "apple-192", "apple-193"] {
            XCTAssertEqual(byID[id]?.steps?.count, 3, "文本选择扩展应说明连续按键的顺序：\(id)")
        }
        XCTAssertEqual(byID["apple-46"]?.steps, [
            "选中项目，或准备打开文件对话框", "按 ⌘O", "在对话框中选择文件并打开（如需要）"
        ])
        XCTAssertEqual(byID["apple-56"]?.steps, [
            "在访达中选中项目", "按空格键", "再次按空格键关闭快速查看"
        ])
        XCTAssertEqual(byID["finder-apple-104"]?.steps, [
            "在访达中选中项目", "按 ⌃⌘A", "在原位置生成替身"
        ])
        XCTAssertEqual(byID["finder-apple-110"]?.steps, [
            "在访达中选中文件", "按 ⌘Y", "查看快速预览"
        ])
        XCTAssertEqual(byID["finder-apple-111"]?.steps, [
            "在访达中选中一个或多个文件", "按 ⌥⌘Y", "浏览快速查看幻灯片"
        ])
        XCTAssertEqual(byID["finder-apple-121"]?.steps, [
            "切换到访达列表视图", "选中文件夹", "按 → 展开文件夹"
        ])
        XCTAssertEqual(byID["finder-apple-122"]?.steps, [
            "切换到访达列表视图", "选中已展开的文件夹", "按 ← 收起文件夹"
        ])
        XCTAssertEqual(byID["finder-apple-94"]?.steps, [
            "在访达中选中项目", "按 ⌃⇧⌘T", "项目添加到程序坞"
        ])
        XCTAssertEqual(byID["finder-apple-98"]?.steps, [
            "在访达中选中项目", "按 ⌃⌘T", "项目添加到边栏"
        ])
        XCTAssertEqual(byID["apple-213"]?.steps, [
            "在文稿中按 ⇧⌘S", "输入文件名并选择位置", "点击存储"
        ])
        XCTAssertEqual(byID["apple-215"]?.steps, [
            "选中要放大的内容", "按 ⇧⌘+", "再次按下可继续放大"
        ])
    }
}
