import AppKit
import SwiftUI
import KeyFindCore

struct SearchPanelView: View {
    @ObservedObject var model: SearchPanelViewModel
    @FocusState private var isSearchFocused: Bool
    private let close: () -> Void

    init(model: SearchPanelViewModel, close: @escaping () -> Void) {
        self.model = model
        self.close = close
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.10), in: Circle())
                TextField("搜索操作或快捷键", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: UIConstants.Typography.searchFieldSize, weight: .regular))
                    .focused($isSearchFocused)
                    .onSubmit { if let shortcut = model.selectedShortcut() { model.copy(shortcut) } }
                if let preferredAppInfo = model.preferredAppInfo {
                    Label(preferredAppInfo.displayName, systemImage: "scope")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.055), in: Capsule())
                        .help("按当前应用优先排序")
                }
                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("清除搜索")
                } else {
                    Text(model.settings.globalHotKey.displayName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.055), in: Capsule())
                        .help("打开搜索面板的快捷键")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: UIConstants.Panel.searchBarHeight)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(Color.primary.opacity(0.055)))
            .padding(.horizontal, 10)
            .padding(.top, 10)
            Divider().opacity(0.35).padding(.top, 10)

            if model.query.isEmpty && model.browseCategory == nil && !model.favoritesOnly {
                DiscoveryView(
                    recentSearches: model.settings.recentSearches,
                    favoriteCount: model.favoriteCount,
                    onRecentSearch: model.selectRecentSearch,
                    onFavorites: model.toggleFavoritesOnly,
                    onCategory: model.browse
                )
            } else {
                if model.favoritesOnly {
                    HStack {
                        Text("收藏的快捷键")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Button("返回") { model.toggleFavoritesOnly() }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                if let category = model.browseCategory {
                    HStack(spacing: 8) {
                        Button {
                            model.clearBrowse()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("返回")
                        categoryTitle(category)
                        Spacer()
                        Text("共 \(model.totalResultCount) 条")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                if model.browseCategory == nil && !model.results.isEmpty && model.availableSources.count > 1 {
                    SourceFilterView(
                        sources: model.availableSources,
                        selectedSource: model.selectedSource,
                        onSelect: model.selectSource
                    )
                    .padding(.top, 9)
                }
                if !model.results.isEmpty {
                    HStack {
                        Text("快捷键")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(model.resultSummary)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, model.requestedApp == nil ? (model.browseCategory == nil ? 10 : 4) : 7)
                }
                Divider().opacity(0.35).padding(.top, model.results.isEmpty ? 0 : 8)
                if model.results.isEmpty {
                    VStack(spacing: 6) {
                        Text(model.catalogError.map { _ in "快捷键数据加载失败" } ?? (model.favoritesOnly ? "还没有收藏的快捷键" : "没有找到匹配的快捷键"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        if model.catalogError == nil && !model.favoritesOnly && !model.query.isEmpty {
                            Text("试试“截图”“移动文件”或“Chrome 新标签页”")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 8) {
                                Button("提交缺失快捷键") { model.openIssueReport() }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.accentColor)
                                Link("查看贡献指南", destination: URL(string: "https://github.com/YinBHan/KeyFind/blob/main/CONTRIBUTING.md")!)
                                    .font(.system(size: 10))
                            }
                        }
                        if let catalogError = model.catalogError {
                            Text(catalogError)
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                        }
                        if let info = model.requestedAppInfo {
                            Text("\(info.displayName) · \(model.requestedAppCount) 个快捷键")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                            Link("查看官方快捷键 ↗", destination: info.sourceURL)
                                .font(.system(size: 10))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 2) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, shortcut in
                                ShortcutRow(
                                    shortcut: shortcut,
                                    selected: index == model.selectedIndex,
                                    favorite: model.settings.favoriteIDs.contains(shortcut.id),
                                    copied: model.copiedShortcutID == shortcut.id,
                                    expanded: model.expandedShortcutIDs.contains(shortcut.id),
                                    onCopy: { model.copy(shortcut) },
                                    onCopySymbol: { model.copy(shortcut, format: .symbol) },
                                    onFavorite: { model.toggleFavorite(shortcut) },
                                    onToggleExpanded: { model.toggleExpanded(shortcut) }
                                )
                                    .onHover { if $0 { model.selectedIndex = index } }
                            }
                            if model.canShowMore {
                                Button {
                                    model.showMore()
                                } label: {
                                    let remaining = max(model.totalResultCount - model.results.count, 0)
                                    Label("显示更多 (还有 \(remaining) 条)", systemImage: "chevron.down")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(MoreResultsButtonStyle())
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: UIConstants.Panel.maxResultsHeight)
                    Divider().opacity(0.55)
                    HStack {
                        Text("↑ ↓ 选择   ↵ 复制   esc 关闭")
                        Spacer()
                        Link("官方来源 ↗", destination: model.selectedShortcut().flatMap { URL(string: $0.sourceURL) } ?? URL(string: "https://support.apple.com/zh-cn/102650")!)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
            }
        }
        .frame(width: UIConstants.Panel.width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous).stroke(.primary.opacity(0.13)))
        .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
        .onAppear {
            isSearchFocused = true
            resizePanel()
        }
        .onChange(of: model.query) { _ in
            resizePanel()
        }
        .onChange(of: model.browseCategory) { _ in
            resizePanel()
        }
        .onChange(of: model.selectedSource) { _ in
            resizePanel()
        }
        .onChange(of: model.favoritesOnly) { _ in
            resizePanel()
        }
        .onChange(of: model.displayedLimit) { _ in
            resizePanel()
        }
        .onChange(of: model.expandedShortcutIDs) { _ in
            resizePanel()
        }
        .onExitCommand(perform: close)
        .onMoveCommand { model.moveSelection($0) }
    }

    func refreshLayout() {
        DispatchQueue.main.async {
            self.resizePanel()
        }
    }

    private func resizePanel() {
        DispatchQueue.main.async {
            guard let panel = NSApp.windows.first(where: { $0 is SearchPanel }) as? SearchPanel else { return }
            let resultHeight = resultsViewportHeight
            let extraHeight: CGFloat
            if model.query.isEmpty && model.browseCategory == nil && !model.favoritesOnly {
                let homeContentHeight = model.settings.recentSearches.isEmpty ? UIConstants.Panel.discoveryCompactHeight : UIConstants.Panel.discoveryRecentHeight
                extraHeight = UIConstants.Panel.contentChromeHeight + homeContentHeight
            } else {
                let headingHeight: CGFloat = model.favoritesOnly || model.browseCategory != nil ? 30 : 0
                let sourceHeight: CGFloat = model.browseCategory == nil && !model.results.isEmpty && model.availableSources.count > 1 ? 36 : 0
                let summaryHeight: CGFloat = model.results.isEmpty ? 0 : 32
                let footerHeight: CGFloat = model.results.isEmpty ? 0 : 38
                let emptyStateHeight: CGFloat = model.results.isEmpty ? 112 : 0
                extraHeight = UIConstants.Panel.contentChromeHeight + headingHeight + sourceHeight + summaryHeight + footerHeight + emptyStateHeight + resultHeight
            }
            panel.resize(to: NSSize(width: UIConstants.Panel.width, height: extraHeight))
        }
    }

    private var resultsViewportHeight: CGFloat {
        let rowsHeight = model.results.reduce(CGFloat.zero) { total, shortcut in
            let stepCount = model.expandedShortcutIDs.contains(shortcut.id) ? shortcut.steps?.count ?? 0 : 0
            let expandedContentHeight = stepCount > 0 ? 8 + CGFloat(stepCount) * 18 : 0
            return total + 58 + expandedContentHeight
        }
        let listPadding = UIConstants.Panel.listPadding
        let moreButtonHeight = model.canShowMore ? UIConstants.Panel.moreButtonHeight : 0
        return min(UIConstants.Panel.maxResultsHeight, rowsHeight + moreButtonHeight + listPadding)
    }

    private func categoryTitle(_ category: ShortcutCategory) -> some View {
        Text(category.rawValue)
            .font(.system(size: 11, weight: .semibold))
    }
}

private struct MoreResultsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .padding(.vertical, 7)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.accentColor.opacity(0.13)))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
