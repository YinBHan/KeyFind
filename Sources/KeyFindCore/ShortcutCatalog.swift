import Foundation

public enum ShortcutCatalogError: LocalizedError, Equatable {
    case missingResource
    case invalidData(String)
    case duplicateIDs([String])
    case duplicateSources
    case duplicateAliases([String])

    public var errorDescription: String? {
        switch self {
        case .missingResource:
            return "找不到快捷键数据文件。"
        case .invalidData(let message):
            return "快捷键数据无效：\(message)"
        case .duplicateIDs(let ids):
            return "快捷键数据存在重复 ID：\(ids.joined(separator: ", "))"
        case .duplicateSources:
            return "应用快捷键来源存在重复应用。"
        case .duplicateAliases(let aliases):
            return "应用快捷键来源存在重复别名：\(aliases.joined(separator: ", "))"
        }
    }
}

public final class ShortcutCatalog: @unchecked Sendable {
    private let bundle: Bundle
    public let sourceURL = URL(string: "https://support.apple.com/zh-cn/102650")!
    public let appSources: [ShortcutAppInfo]
    public let sourceRegistry: ShortcutSourceRegistry

    public init(bundle: Bundle? = nil) {
        self.bundle = bundle ?? .module
        self.sourceRegistry = .default
        self.appSources = sourceRegistry.descriptors.map { ShortcutAppInfo(app: $0.app, sourceURL: $0.sourceURL) }
    }

    public func load() throws -> [Shortcut] {
        guard let url = bundle.url(forResource: "shortcuts", withExtension: "json") else {
            throw ShortcutCatalogError.missingResource
        }
        do {
            let data = try Data(contentsOf: url)
            let shortcuts = try JSONDecoder().decode([Shortcut].self, from: data)
            try validate(shortcuts, expectedScope: .system, expectedBundleIdentifier: nil, sourceName: "macOS")
            let grouped = Dictionary(grouping: shortcuts, by: \.id)
            let duplicates = grouped.filter { $0.value.count > 1 }.map(\.key).sorted()
            guard duplicates.isEmpty else { throw ShortcutCatalogError.duplicateIDs(duplicates) }
            guard shortcuts.allSatisfy({ $0.scope == .system && $0.appIdentifier == nil }) else {
                throw ShortcutCatalogError.invalidData("macOS 系统快捷键数据包含应用来源项目。")
            }
            return shortcuts
        } catch let error as ShortcutCatalogError {
            throw error
        } catch {
            throw ShortcutCatalogError.invalidData(error.localizedDescription)
        }
    }

    public func loadChrome() throws -> [Shortcut] {
        guard let descriptor = sourceRegistry.descriptor(for: .chrome) else {
            throw ShortcutCatalogError.invalidData("找不到 Chrome 的快捷键来源配置。")
        }
        return try load(descriptor)
    }

    public func load(_ app: ShortcutApp) throws -> [Shortcut] {
        guard let descriptor = sourceRegistry.descriptor(for: app) else {
            throw ShortcutCatalogError.invalidData("找不到 \(app.rawValue) 的快捷键来源配置。")
        }
        return try load(descriptor)
    }

    public func loadFinder() throws -> [Shortcut] {
        guard let descriptor = sourceRegistry.descriptor(for: .finder) else {
            throw ShortcutCatalogError.invalidData("找不到访达的快捷键来源配置。")
        }
        return try load(descriptor)
    }

    public func loadSafari() throws -> [Shortcut] {
        guard let descriptor = sourceRegistry.descriptor(for: .safari) else {
            throw ShortcutCatalogError.invalidData("找不到 Safari 的快捷键来源配置。")
        }
        return try load(descriptor)
    }

    public func loadVSCode() throws -> [Shortcut] {
        guard let descriptor = sourceRegistry.descriptor(for: .vscode) else {
            throw ShortcutCatalogError.invalidData("找不到 VS Code 的快捷键来源配置。")
        }
        return try load(descriptor)
    }

    public func loadChatGPT() throws -> [Shortcut] {
        guard let descriptor = sourceRegistry.descriptor(for: .chatgpt) else {
            throw ShortcutCatalogError.invalidData("找不到 ChatGPT 的快捷键来源配置。")
        }
        return try load(descriptor)
    }

    private func load(_ descriptor: ShortcutSourceDescriptor) throws -> [Shortcut] {
        guard let url = bundle.url(forResource: descriptor.resourceName, withExtension: "json") else {
            throw ShortcutCatalogError.missingResource
        }
        do {
            let data = try Data(contentsOf: url)
            let shortcuts = try JSONDecoder().decode([Shortcut].self, from: data)
            try validate(shortcuts, expectedScope: .app, expectedBundleIdentifier: descriptor.bundleIdentifier, sourceName: descriptor.displayName)
            let grouped = Dictionary(grouping: shortcuts, by: \.id)
            let duplicates = grouped.filter { $0.value.count > 1 }.map(\.key).sorted()
            guard duplicates.isEmpty else { throw ShortcutCatalogError.duplicateIDs(duplicates) }
            guard shortcuts.allSatisfy({ $0.scope == .app && $0.appIdentifier == descriptor.bundleIdentifier }) else {
                throw ShortcutCatalogError.invalidData("\(descriptor.displayName) 快捷键数据包含其他来源的项目。")
            }
            return shortcuts
        } catch let error as ShortcutCatalogError {
            throw error
        } catch {
            throw ShortcutCatalogError.invalidData(error.localizedDescription)
        }
    }

    public func loadAll() throws -> [Shortcut] {
        try sourceRegistry.validate()
        let sources = try load() + sourceRegistry.descriptors.flatMap { try load($0) }
        let grouped = Dictionary(grouping: sources, by: \.id)
        let duplicates = grouped.filter { $0.value.count > 1 }.map(\.key).sorted()
        guard duplicates.isEmpty else { throw ShortcutCatalogError.duplicateIDs(duplicates) }
        return sources
    }

    private func validate(
        _ shortcuts: [Shortcut],
        expectedScope: ShortcutScope,
        expectedBundleIdentifier: String?,
        sourceName: String
    ) throws {
        for shortcut in shortcuts {
            guard !shortcut.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ShortcutCatalogError.invalidData("\(sourceName) 快捷键缺少 ID。")
            }
            guard !shortcut.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ShortcutCatalogError.invalidData("\(sourceName) 快捷键 \(shortcut.id) 缺少标题。")
            }
            guard !shortcut.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ShortcutCatalogError.invalidData("\(sourceName) 快捷键 \(shortcut.id) 缺少说明。")
            }
            guard !shortcut.keys.symbolText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !shortcut.keys.readableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ShortcutCatalogError.invalidData("\(sourceName) 快捷键 \(shortcut.id) 缺少按键说明。")
            }
            guard !shortcut.searchTerms.isEmpty,
                  shortcut.searchTerms.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw ShortcutCatalogError.invalidData("\(sourceName) 快捷键 \(shortcut.id) 缺少搜索词。")
            }
            guard let sourceURL = URL(string: shortcut.sourceURL),
                  sourceURL.scheme == "https",
                  sourceURL.host != nil else {
                throw ShortcutCatalogError.invalidData("\(sourceName) 快捷键 \(shortcut.id) 的来源链接无效。")
            }
            guard shortcut.scope == expectedScope else {
                throw ShortcutCatalogError.invalidData("\(sourceName) 快捷键数据包含错误的来源范围。")
            }
            if let expectedBundleIdentifier {
                guard shortcut.appIdentifier == expectedBundleIdentifier else {
                    throw ShortcutCatalogError.invalidData("\(sourceName) 快捷键数据包含错误的 Bundle ID。")
                }
            } else if shortcut.appIdentifier != nil {
                throw ShortcutCatalogError.invalidData("\(sourceName) 系统快捷键不应包含应用来源。")
            }
        }
    }
}
