import Foundation

public struct ShortcutSearchService: Sendable {
    private let shortcuts: [Shortcut]
    private let sourceRegistry: ShortcutSourceRegistry

    public init(shortcuts: [Shortcut], sourceRegistry: ShortcutSourceRegistry = .default) {
        self.shortcuts = shortcuts
        self.sourceRegistry = sourceRegistry
    }

    public func search(_ query: String, limit: Int = 5) -> [Shortcut] {
        guard limit > 0 else { return [] }
        return rankedMatches(for: query).prefix(limit).map(\.0)
    }

    public func matchingCount(for query: String) -> Int {
        rankedMatches(for: query).count
    }

    public func search(_ query: String, limit: Int = 5, preferredApp: ShortcutApp?) -> [Shortcut] {
        guard limit > 0 else { return [] }
        return rankedMatches(for: query, preferredApp: preferredApp).prefix(limit).map(\.0)
    }

    public func matchingCount(for query: String, preferredApp: ShortcutApp?) -> Int {
        rankedMatches(for: query, preferredApp: preferredApp).count
    }

    public func appSuggestions(for app: ShortcutApp, limit: Int = 6) -> [Shortcut] {
        guard limit > 0 else { return [] }
        return shortcuts.filter { $0.app == app }.prefix(limit).map { $0 }
    }

    public func count(for app: ShortcutApp) -> Int {
        shortcuts.reduce(into: 0) { count, shortcut in
            if shortcut.app == app { count += 1 }
        }
    }

    public func shortcuts(withIDs ids: Set<String>, limit: Int = 6, source: ShortcutSource? = nil) -> [Shortcut] {
        guard limit > 0 else { return [] }
        return shortcuts
            .filter { ids.contains($0.id) && sourceMatches($0, source) }
            .prefix(limit)
            .map { $0 }
    }

    public func count(withIDs ids: Set<String>, source: ShortcutSource? = nil) -> Int {
        shortcuts.reduce(into: 0) { count, shortcut in
            if ids.contains(shortcut.id) && sourceMatches(shortcut, source) { count += 1 }
        }
    }

    public var availableSources: [ShortcutSource] {
        var sources: [ShortcutSource] = []
        if shortcuts.contains(where: { $0.scope == .system }) { sources.append(.system) }
        for descriptor in sourceRegistry.descriptors where shortcuts.contains(where: { $0.app == descriptor.app }) {
            sources.append(.app(descriptor.app))
        }
        return sources
    }

    public func search(_ query: String, limit: Int = 5, preferredApp: ShortcutApp? = nil, source: ShortcutSource?) -> [Shortcut] {
        guard limit > 0 else { return [] }
        return rankedMatches(for: query, preferredApp: preferredApp, source: source).prefix(limit).map(\.0)
    }

    public func matchingCount(for query: String, preferredApp: ShortcutApp? = nil, source: ShortcutSource?) -> Int {
        rankedMatches(for: query, preferredApp: preferredApp, source: source).count
    }

    public func shortcuts(in source: ShortcutSource, limit: Int = 6) -> [Shortcut] {
        guard limit > 0 else { return [] }
        return shortcuts.filter { $0.source == source }.prefix(limit).map { $0 }
    }

    public func count(in category: ShortcutCategory) -> Int {
        shortcuts.reduce(into: 0) { count, shortcut in
            if shortcut.category == category { count += 1 }
        }
    }

    private func rankedMatches(for query: String) -> [(Shortcut, Double)] {
        rankedMatches(for: query, preferredApp: nil)
    }

    private func rankedMatches(for query: String, preferredApp: ShortcutApp?) -> [(Shortcut, Double)] {
        rankedMatches(for: query, preferredApp: preferredApp, source: nil)
    }

    private func rankedMatches(for query: String, preferredApp: ShortcutApp?, source: ShortcutSource?) -> [(Shortcut, Double)] {
        let (normalizedQuery, requestedApp, isAppOnlyQuery) = resolveAppPrefix(in: query)
        let targetApp = requestedApp ?? preferredApp
        let effectiveSource = requestedApp.map(ShortcutSource.app) ?? source
        if isAppOnlyQuery, let requestedApp {
            return shortcuts.enumerated().compactMap { index, shortcut in
                guard shortcut.app == requestedApp, sourceMatches(shortcut, effectiveSource) else { return nil }
                return (shortcut, 100.0 - Double(index) / 1_000)
            }
        }
        guard !normalizedQuery.isEmpty else { return [] }

        return shortcuts.enumerated().compactMap { index, shortcut in
            guard sourceMatches(shortcut, effectiveSource) else { return nil }
            let title = Self.normalize(shortcut.title)
            let terms = shortcut.searchTerms.map(Self.normalize)
            let description = Self.normalize(shortcut.description)
            var score = -Double(index) / 1_000

            if title == normalizedQuery {
                score += 100
            } else if title.contains(normalizedQuery) {
                score += 75
            }
            if terms.contains(normalizedQuery) {
                score += 50
            } else if terms.contains(where: { $0.contains(normalizedQuery) }) {
                score += 35
            }
            if description.contains(normalizedQuery) {
                score += 20
            }
            if let targetApp {
                if shortcut.app == targetApp {
                    score += requestedApp == targetApp ? 80 : 12
                } else if requestedApp != nil, shortcut.scope == .app {
                    return nil
                }
            }

            return score > 0 ? (shortcut, score) : nil
        }
        .sorted { $0.1 > $1.1 }
    }

    private func sourceMatches(_ shortcut: Shortcut, _ source: ShortcutSource?) -> Bool {
        guard let source else { return true }
        return shortcut.source == source
    }

    private func resolveAppPrefix(in query: String) -> (query: String, app: ShortcutApp?, isAppOnlyQuery: Bool) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = Self.normalize(trimmed)
        if let app = sourceRegistry.app(matchingPrefixIn: normalized), let descriptor = sourceRegistry.descriptor(for: app) {
            let alias = descriptor.searchAliases
                .map(Self.normalize)
                .filter { normalized.hasPrefix($0) }
                .max { $0.count < $1.count } ?? ""
            let suffix = String(normalized.dropFirst(alias.count))
            return (suffix, app, suffix.isEmpty)
        }
        return (normalized, nil, false)
    }

    public func shortcuts(in category: ShortcutCategory, limit: Int = 6) -> [Shortcut] {
        guard limit > 0 else { return [] }
        return shortcuts
            .filter { $0.category == category }
            .prefix(limit)
            .map { $0 }
    }

    public static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[，。！？、,.!?；;：:（）()「」『』“”‘’\"'、·—–-]", with: "", options: .regularExpression)
    }
}
