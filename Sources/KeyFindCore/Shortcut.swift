import Foundation

public enum ShortcutScope: String, Codable, Equatable, Sendable {
    case system
    case app
}

public enum ShortcutCategory: String, Codable, CaseIterable, Equatable, Sendable {
    case common = "常用操作"
    case sleepSystem = "睡眠与系统"
    case finderSystem = "访达与系统"
    case textEditing = "文本编辑"
    case accessibility = "辅助功能"
    case otherAccessibility = "其他辅助功能"
}

public enum ShortcutApp: String, Codable, CaseIterable, Equatable, Sendable {
    case chrome = "Google Chrome"
    case finder = "访达"
    case safari = "Safari"
    case vscode = "Visual Studio Code"
    case chatgpt = "ChatGPT"
    case terminal = "终端"
    case xcode = "Xcode"
    case figma = "Figma"
    case notion = "Notion"
    case raycast = "Raycast"

    public var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .finder: return "com.apple.finder"
        case .safari: return "com.apple.Safari"
        case .vscode: return "com.microsoft.VSCode"
        case .chatgpt: return "com.openai.chat"
        case .terminal: return "com.apple.Terminal"
        case .xcode: return "com.apple.dt.Xcode"
        case .figma: return "com.figma.Desktop"
        case .notion: return "notion.id"
        case .raycast: return "com.raycast.macos"
        }
    }

    public var searchAliases: [String] {
        switch self {
        case .chrome: return ["谷歌", "谷歌浏览器", "Chrome", "Google Chrome", "浏览器"]
        case .finder: return ["访达", "Finder", "文件管理", "文件管理器"]
        case .safari: return ["Safari", "苹果浏览器", "苹果自带浏览器", "浏览器 Safari"]
        case .vscode: return ["VS Code", "Visual Studio Code", "代码编辑器"]
        case .chatgpt: return ["ChatGPT", "OpenAI ChatGPT"]
        case .terminal: return ["终端", "Terminal", "命令行", "终端机"]
        case .xcode: return ["Xcode", "苹果开发", "iOS 开发"]
        case .figma: return ["Figma", "设计工具", "原型设计"]
        case .notion: return ["Notion", "笔记", "知识库", "文档"]
        case .raycast: return ["Raycast", "启动器", "命令启动器"]
        }
    }
}

public struct ShortcutAppInfo: Equatable, Sendable {
    public let app: ShortcutApp
    public let displayName: String
    public let bundleIdentifier: String
    public let searchAliases: [String]
    public let sourceURL: URL

    public init(app: ShortcutApp, sourceURL: URL) {
        self.app = app
        self.displayName = app.rawValue
        self.bundleIdentifier = app.bundleIdentifier
        self.searchAliases = app.searchAliases
        self.sourceURL = sourceURL
    }
}

public enum ShortcutSource: Hashable, Equatable, Sendable {
    case system
    case app(ShortcutApp)

    public var displayName: String {
        switch self {
        case .system: return "macOS"
        case .app(let app): return app.rawValue
        }
    }
}

public struct ShortcutKey: Codable, Equatable, Sendable {
    public let modifiers: [String]
    public let key: String
    public let symbolText: String
    public let readableText: String

    public init(modifiers: [String], key: String, symbolText: String? = nil, readableText: String) {
        self.modifiers = modifiers
        self.key = key
        self.symbolText = symbolText ?? (modifiers + [key]).joined(separator: " ")
        self.readableText = readableText
    }
}

public struct Shortcut: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let category: ShortcutCategory
    public let keys: ShortcutKey
    public let searchTerms: [String]
    public let scope: ShortcutScope
    public let appIdentifier: String?
    public let sourceURL: String
    public let caution: String?
    public let steps: [String]?

    public var app: ShortcutApp? {
        guard scope == .app, let appIdentifier else { return nil }
        return ShortcutApp.allCases.first { $0.bundleIdentifier == appIdentifier }
    }

    public var source: ShortcutSource {
        if let app { return .app(app) }
        return .system
    }

    public init(
        id: String,
        title: String,
        description: String,
        category: ShortcutCategory,
        keys: ShortcutKey,
        searchTerms: [String],
        scope: ShortcutScope,
        appIdentifier: String?,
        sourceURL: String,
        caution: String?,
        steps: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.keys = keys
        self.searchTerms = searchTerms
        self.scope = scope
        self.appIdentifier = appIdentifier
        self.sourceURL = sourceURL
        self.caution = caution
        self.steps = steps
    }
}
