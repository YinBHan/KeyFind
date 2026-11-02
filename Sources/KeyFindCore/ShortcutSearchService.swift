import Foundation

public struct ShortcutSearchService: Sendable {
    private struct PinyinVariants: Sendable {
        let full: String
        let initials: String
    }

    private struct SearchDocument: Sendable {
        let title: String
        let titlePinyin: PinyinVariants
        let terms: [(value: String, pinyin: PinyinVariants)]
        let description: String
        let descriptionPinyin: PinyinVariants
    }

    private let shortcuts: [Shortcut]
    private let sourceRegistry: ShortcutSourceRegistry
    private let documents: [SearchDocument]

    public init(shortcuts: [Shortcut], sourceRegistry: ShortcutSourceRegistry = .default) {
        self.shortcuts = shortcuts
        self.sourceRegistry = sourceRegistry
        self.documents = shortcuts.map { shortcut in
            SearchDocument(
                title: Self.normalize(shortcut.title),
                titlePinyin: Self.pinyinVariants(for: shortcut.title),
                terms: shortcut.searchTerms.map { term in
                    (value: Self.normalize(term), pinyin: Self.pinyinVariants(for: term))
                },
                description: Self.normalize(shortcut.description),
                descriptionPinyin: Self.pinyinVariants(for: shortcut.description)
            )
        }
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

    /// Searches the catalog and ranks matches by relevance.
    ///
    /// Scores are additive: exact title matches receive 100 points and title
    /// containment receives 75; pinyin title matches receive 88 or 62. Search
    /// term matches receive 50 or 35 (44 or 29 for pinyin), while description
    /// matches receive 20 (17 or 14 for pinyin). A requested app prefix adds
    /// 80 points to that app and excludes other app-specific shortcuts; the
    /// frontmost preferred app adds 12. A small catalog-index penalty keeps
    /// otherwise equal results in their original order.
    ///
    /// - Parameters:
    ///   - query: The user's query, optionally beginning with an app alias.
    ///   - preferredApp: The frontmost app whose shortcuts should rank higher.
    ///   - source: An optional source filter applied before scoring.
    /// - Returns: Matching shortcuts paired with their scores, highest first.
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
            let document = documents[index]
            var score = -Double(index) / 1_000
            var matched = false

            let titleScore = Self.matchScore(
                value: document.title,
                pinyin: document.titlePinyin,
                query: normalizedQuery,
                exactScore: 100,
                containsScore: 75,
                pinyinExactScore: 88,
                pinyinContainsScore: 62
            )
            if let titleScore {
                matched = true
                score += titleScore
            }

            let termScores = document.terms.compactMap { term in
                Self.matchScore(
                    value: term.value,
                    pinyin: term.pinyin,
                    query: normalizedQuery,
                    exactScore: 50,
                    containsScore: 35,
                    pinyinExactScore: 44,
                    pinyinContainsScore: 29
                )
            }
            if let termScore = termScores.max() {
                matched = true
                score += termScore
            }

            if let descriptionScore = Self.matchScore(
                value: document.description,
                pinyin: document.descriptionPinyin,
                query: normalizedQuery,
                exactScore: 20,
                containsScore: 20,
                pinyinExactScore: 17,
                pinyinContainsScore: 14
            ) {
                matched = true
                score += descriptionScore
            }

            guard matched else { return nil }
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

    private static func pinyinVariants(for value: String) -> PinyinVariants {
        let latin = value.applyingTransform(.toLatin, reverse: false) ?? value
        let unaccented = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
        let full = normalize(unaccented)
        let initials = latin
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .lowercased()
        return PinyinVariants(full: full, initials: initials)
    }

    private static func matchScore(
        value: String,
        pinyin: PinyinVariants,
        query: String,
        exactScore: Double,
        containsScore: Double,
        pinyinExactScore: Double,
        pinyinContainsScore: Double
    ) -> Double? {
        if value == query { return exactScore }
        if value.contains(query) { return containsScore }
        guard query.count >= 2 else { return nil }
        if pinyin.full == query || pinyin.initials == query { return pinyinExactScore }
        if pinyin.full.contains(query) || pinyin.initials.contains(query) { return pinyinContainsScore }
        return nil
    }
}
