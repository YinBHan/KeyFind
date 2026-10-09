import Foundation

public struct ShortcutSourceDescriptor: Equatable, Sendable {
    public let app: ShortcutApp
    public let displayName: String
    public let bundleIdentifier: String
    public let searchAliases: [String]
    public let sourceURL: URL
    public let resourceName: String

    public init(app: ShortcutApp, displayName: String, bundleIdentifier: String, searchAliases: [String], sourceURL: URL, resourceName: String) {
        self.app = app
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.searchAliases = searchAliases
        self.sourceURL = sourceURL
        self.resourceName = resourceName
    }

}

public struct ShortcutSourceRegistry: Equatable, Sendable {
    public let descriptors: [ShortcutSourceDescriptor]

    public init(descriptors: [ShortcutSourceDescriptor]? = nil) {
        self.descriptors = descriptors ?? Self.defaultDescriptors
    }

    public static let `default` = ShortcutSourceRegistry()

    private static let defaultDescriptors: [ShortcutSourceDescriptor] = [
        ShortcutSourceDescriptor(app: .chrome, displayName: "Google Chrome", bundleIdentifier: ShortcutApp.chrome.bundleIdentifier, searchAliases: ShortcutApp.chrome.searchAliases, sourceURL: URL(string: "https://support.google.com/chrome/answer/157179")!, resourceName: "chrome-shortcuts"),
        ShortcutSourceDescriptor(app: .finder, displayName: "访达", bundleIdentifier: ShortcutApp.finder.bundleIdentifier, searchAliases: ShortcutApp.finder.searchAliases, sourceURL: URL(string: "https://support.apple.com/zh-cn/102650")!, resourceName: "finder-shortcuts"),
        ShortcutSourceDescriptor(app: .safari, displayName: "Safari", bundleIdentifier: ShortcutApp.safari.bundleIdentifier, searchAliases: ShortcutApp.safari.searchAliases, sourceURL: URL(string: "https://support.apple.com/zh-cn/guide/safari/keyboard-shortcuts-and-gestures-cpsh003/mac")!, resourceName: "safari-shortcuts"),
        ShortcutSourceDescriptor(app: .vscode, displayName: "Visual Studio Code", bundleIdentifier: ShortcutApp.vscode.bundleIdentifier, searchAliases: ShortcutApp.vscode.searchAliases, sourceURL: URL(string: "https://code.visualstudio.com/docs/configure/keybindings")!, resourceName: "vscode-shortcuts"),
        ShortcutSourceDescriptor(app: .chatgpt, displayName: "ChatGPT", bundleIdentifier: ShortcutApp.chatgpt.bundleIdentifier, searchAliases: ShortcutApp.chatgpt.searchAliases, sourceURL: URL(string: "https://help.openai.com/en/articles/9982051-using-the-chatgpt-mac-app")!, resourceName: "chatgpt-shortcuts"),
        ShortcutSourceDescriptor(app: .terminal, displayName: "终端", bundleIdentifier: ShortcutApp.terminal.bundleIdentifier, searchAliases: ShortcutApp.terminal.searchAliases, sourceURL: URL(string: "https://support.apple.com/guide/terminal/keyboard-shortcuts-trmlshtcts/mac")!, resourceName: "terminal-shortcuts"),
        ShortcutSourceDescriptor(app: .xcode, displayName: "Xcode", bundleIdentifier: ShortcutApp.xcode.bundleIdentifier, searchAliases: ShortcutApp.xcode.searchAliases, sourceURL: URL(string: "https://developer.apple.com/library/archive/documentation/IDEs/Conceptual/xcode_help-command_shortcuts/MenuCommands/MenuCommands014.html")!, resourceName: "xcode-shortcuts"),
        ShortcutSourceDescriptor(app: .figma, displayName: "Figma", bundleIdentifier: ShortcutApp.figma.bundleIdentifier, searchAliases: ShortcutApp.figma.searchAliases, sourceURL: URL(string: "https://help.figma.com/hc/en-us/articles/360040328653-Use-Figma-products-with-a-keyboard")!, resourceName: "figma-shortcuts"),
        ShortcutSourceDescriptor(app: .notion, displayName: "Notion", bundleIdentifier: ShortcutApp.notion.bundleIdentifier, searchAliases: ShortcutApp.notion.searchAliases, sourceURL: URL(string: "https://www.notion.com/help/keyboard-shortcuts")!, resourceName: "notion-shortcuts"),
        ShortcutSourceDescriptor(app: .raycast, displayName: "Raycast", bundleIdentifier: ShortcutApp.raycast.bundleIdentifier, searchAliases: ShortcutApp.raycast.searchAliases, sourceURL: URL(string: "https://manual.raycast.com/keyboard-shortcuts")!, resourceName: "raycast-shortcuts")
    ]

    public func descriptor(for app: ShortcutApp) -> ShortcutSourceDescriptor? {
        descriptors.first { $0.app == app }
    }

    public func app(forAlias alias: String) -> ShortcutApp? {
        let normalized = ShortcutSearchService.normalize(alias)
        return descriptors.first { descriptor in
            descriptor.searchAliases.contains { ShortcutSearchService.normalize($0) == normalized }
        }?.app
    }

    public func app(matchingPrefixIn normalizedQuery: String) -> ShortcutApp? {
        descriptors
            .flatMap { descriptor in descriptor.searchAliases.map { (ShortcutSearchService.normalize($0), descriptor.app) } }
            .filter { !($0.0.isEmpty) && normalizedQuery.hasPrefix($0.0) }
            .max { $0.0.count < $1.0.count }?.1
    }

    public func validate() throws {
        let apps = descriptors.map(\.app)
        guard Set(apps).count == apps.count else { throw ShortcutCatalogError.duplicateSources }
        guard descriptors.allSatisfy({ !$0.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ShortcutCatalogError.invalidData("应用快捷键来源缺少显示名称。")
        }
        guard descriptors.allSatisfy({ !$0.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ShortcutCatalogError.invalidData("应用快捷键来源缺少 Bundle ID。")
        }
        guard descriptors.allSatisfy({ !$0.resourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ShortcutCatalogError.invalidData("应用快捷键来源缺少资源名称。")
        }
        guard descriptors.allSatisfy({ $0.sourceURL.scheme == "https" && $0.sourceURL.host != nil }) else {
            throw ShortcutCatalogError.invalidData("应用快捷键来源链接无效。")
        }
        let aliases = descriptors.flatMap { $0.searchAliases.map(ShortcutSearchService.normalize) }
        guard !aliases.contains(where: { $0.isEmpty }) else {
            throw ShortcutCatalogError.invalidData("应用快捷键来源包含空别名。")
        }
        let duplicates = Dictionary(grouping: aliases, by: { $0 }).filter { $0.value.count > 1 }.map(\.key).sorted()
        guard duplicates.isEmpty else { throw ShortcutCatalogError.duplicateAliases(duplicates) }
    }
}
