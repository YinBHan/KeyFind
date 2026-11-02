import AppKit
import SwiftUI
import KeyFindCore

enum ShortcutCopyFormat {
    case symbol
    case readable

    func text(for shortcut: Shortcut) -> String {
        switch self {
        case .symbol: return shortcut.keys.symbolText
        case .readable: return shortcut.keys.readableText
        }
    }
}

@MainActor
final class SearchPanelViewModel: ObservableObject {
    private let pageSize = UIConstants.Search.pageSize

    @Published var query = "" {
        didSet {
            if !query.isEmpty {
                browseCategory = nil
                favoritesOnly = false
            }
            displayedLimit = pageSize
            updateResults()
            selectedIndex = min(selectedIndex, max(results.count - 1, 0))
        }
    }
    @Published private(set) var results: [Shortcut] = []
    @Published private(set) var totalResultCount = 0
    @Published private(set) var displayedLimit = UIConstants.Search.pageSize
    @Published private(set) var catalogError: String?
    @Published var selectedIndex = 0
    @Published private(set) var browseCategory: ShortcutCategory?
    @Published var selectedSource: ShortcutSource?
    @Published var favoritesOnly = false
    @Published var copiedShortcutID: String?
    @Published private(set) var expandedShortcutIDs: Set<String> = []

    let settings: AppSettings
    private let catalog: ShortcutCatalog
    private let sourceRegistry: ShortcutSourceRegistry
    private let searchService: ShortcutSearchService
    private var preferredApp: ShortcutApp?

    var availableSources: [ShortcutSource] { searchService.availableSources }

    var requestedApp: ShortcutApp? {
        let normalized = ShortcutSearchService.normalize(query)
        return sourceRegistry.app(forAlias: normalized)
    }

    var requestedAppInfo: ShortcutAppInfo? {
        guard let requestedApp else { return nil }
        return catalog.appSources.first { $0.app == requestedApp }
    }

    var requestedAppCount: Int {
        guard let requestedApp else { return 0 }
        return searchService.count(for: requestedApp)
    }

    var preferredAppInfo: ShortcutAppInfo? {
        guard let preferredApp else { return nil }
        return catalog.appSources.first { $0.app == preferredApp }
    }

    init(settings: AppSettings) {
        self.settings = settings
        let catalog = ShortcutCatalog()
        self.catalog = catalog
        let registry = catalog.sourceRegistry
        self.sourceRegistry = registry
        let shortcuts: [Shortcut]
        let catalogError: String?
        do {
            shortcuts = try catalog.loadAll()
            catalogError = nil
        } catch {
            shortcuts = []
            catalogError = error.localizedDescription
        }
        self.catalogError = catalogError
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            .flatMap { identifier in registry.descriptors.first { $0.bundleIdentifier == identifier }?.app }
        preferredApp = app
        searchService = ShortcutSearchService(shortcuts: shortcuts, sourceRegistry: registry)
    }

    var canShowMore: Bool { results.count < totalResultCount }

    var resultSummary: String {
        guard totalResultCount > 0 else { return "" }
        if canShowMore {
            return "显示 \(results.count) / \(totalResultCount) 条"
        }
        return "共 \(totalResultCount) 条"
    }

    var favoriteCount: Int { settings.favoriteIDs.count }

    func reset() {
        preferredApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            .flatMap { identifier in sourceRegistry.descriptors.first { $0.bundleIdentifier == identifier }?.app }
        query = ""
        browseCategory = nil
        selectedSource = nil
        results = []
        totalResultCount = 0
        displayedLimit = pageSize
        selectedIndex = 0
        favoritesOnly = false
        copiedShortcutID = nil
        expandedShortcutIDs = []
    }

    func selectRecentSearch(_ value: String) {
        browseCategory = nil
        query = value
    }

    func openIssueReport() {
        NSWorkspace.shared.open(URL(string: "https://github.com/YinBHan/KeyFind/issues/new/choose")!)
    }

    func selectSource(_ source: ShortcutSource?) {
        selectedSource = source
        browseCategory = nil
        displayedLimit = pageSize
        updateResults()
        selectedIndex = min(selectedIndex, max(results.count - 1, 0))
    }

    func toggleFavoritesOnly() {
        favoritesOnly.toggle()
        browseCategory = nil
        displayedLimit = pageSize
        updateResults()
        selectedIndex = min(selectedIndex, max(results.count - 1, 0))
    }

    func browse(_ category: ShortcutCategory) {
        browseCategory = category
        query = ""
        displayedLimit = Int.max
        results = searchService.shortcuts(in: category, limit: Int.max)
        totalResultCount = searchService.count(in: category)
        selectedIndex = 0
    }

    func clearBrowse() {
        browseCategory = nil
        results = []
        totalResultCount = 0
        displayedLimit = pageSize
        selectedIndex = 0
    }

    func showMore() {
        guard canShowMore else { return }
        displayedLimit += pageSize
        updateResults()
    }

    func toggleExpanded(_ shortcut: Shortcut) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if expandedShortcutIDs.contains(shortcut.id) {
                expandedShortcutIDs.remove(shortcut.id)
            } else {
                expandedShortcutIDs.insert(shortcut.id)
            }
        }
    }

    func moveSelection(_ direction: MoveCommandDirection) {
        guard !results.isEmpty else { return }
        if direction == .down { selectedIndex = min(selectedIndex + 1, results.count - 1) }
        if direction == .up { selectedIndex = max(selectedIndex - 1, 0) }
    }

    func selectedShortcut() -> Shortcut? { results.indices.contains(selectedIndex) ? results[selectedIndex] : nil }

    func toggleFavorite(_ shortcut: Shortcut) {
        settings.toggleFavorite(id: shortcut.id)
        if favoritesOnly {
            updateResults()
            selectedIndex = min(selectedIndex, max(results.count - 1, 0))
        }
        objectWillChange.send()
    }

    func copy(_ shortcut: Shortcut, format: ShortcutCopyFormat = .readable) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(format.text(for: shortcut), forType: .string)
        settings.recordSearch(query)
        copiedShortcutID = shortcut.id
        DispatchQueue.main.asyncAfter(deadline: .now() + UIConstants.Animation.copyFeedbackDuration) { [weak self] in
            guard self?.copiedShortcutID == shortcut.id else { return }
            self?.copiedShortcutID = nil
        }
    }

    private func updateResults() {
        if let category = browseCategory {
            let limit = displayedLimit == Int.max ? Int.max : displayedLimit
            results = searchService.shortcuts(in: category, limit: limit)
            totalResultCount = searchService.count(in: category)
        } else {
            if favoritesOnly {
                results = searchService.shortcuts(withIDs: settings.favoriteIDs, limit: displayedLimit, source: selectedSource)
                totalResultCount = searchService.count(withIDs: settings.favoriteIDs, source: selectedSource)
            } else {
                results = searchService.search(query, limit: displayedLimit, preferredApp: preferredApp, source: selectedSource)
                totalResultCount = searchService.matchingCount(for: query, preferredApp: preferredApp, source: selectedSource)
            }
            if !favoritesOnly, results.isEmpty, let requestedApp = sourceRegistry.app(forAlias: query) {
                let requestedSource = ShortcutSource.app(requestedApp)
                if selectedSource == nil || selectedSource == requestedSource {
                    results = searchService.appSuggestions(for: requestedApp, limit: displayedLimit)
                    totalResultCount = searchService.appSuggestions(for: requestedApp, limit: Int.max).count
                }
            }
        }
    }
}
