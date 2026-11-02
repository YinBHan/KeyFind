import SwiftUI
import KeyFindCore

struct DiscoveryView: View {
    let recentSearches: [String]
    let favoriteCount: Int
    let onRecentSearch: (String) -> Void
    let onFavorites: () -> Void
    let onCategory: (ShortcutCategory) -> Void

    private let examples = ["截图", "移动文件", "Chrome 新标签页"]
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onFavorites) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                    Text("收藏的快捷键")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.86))
                    Spacer()
                    Text(favoriteCount > 0 ? "已收藏 \(favoriteCount) 条" : "常用项目")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
            }
            .buttonStyle(DiscoveryRecentStyle())

            VStack(alignment: .leading, spacing: 5) {
                DiscoverySectionHeading(
                    title: recentSearches.isEmpty ? "试试搜索" : "最近搜索",
                    icon: recentSearches.isEmpty ? "sparkle.magnifyingglass" : "clock.arrow.circlepath",
                    tint: recentSearches.isEmpty ? .purple : .secondary
                )
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array((recentSearches.isEmpty ? examples : recentSearches).prefix(UIConstants.Search.recentSearchDisplayLimit)), id: \.self) { value in
                            Button { onRecentSearch(value) } label: {
                                Label(value, systemImage: recentSearches.isEmpty ? "magnifyingglass" : "clock")
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 9)
                                    .frame(height: 28)
                            }
                            .buttonStyle(DiscoveryRecentStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            VStack(alignment: .leading, spacing: 5) {
                DiscoverySectionHeading(title: "浏览分类", icon: "square.grid.2x2", tint: .accentColor)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(ShortcutCategory.allCases, id: \.self) { category in
                        Button { onCategory(category) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: category.symbolName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(category.symbolColor)
                                    .frame(width: 22, height: 22)
                                    .background(category.symbolColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                Text(category.rawValue)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(DiscoveryCategoryStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct DiscoverySectionHeading: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.84))
        }
    }
}

private struct DiscoveryRecentStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary.opacity(0.82))
            .background(Color.primary.opacity(configuration.isPressed ? 0.075 : 0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DiscoveryCategoryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(Color.primary.opacity(configuration.isPressed ? 0.075 : 0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.05)))
    }
}

private extension ShortcutCategory {
    var symbolName: String {
        switch self {
        case .common: return "command.square"
        case .sleepSystem: return "power"
        case .finderSystem: return "folder"
        case .textEditing: return "character.cursor.ibeam"
        case .accessibility: return "accessibility"
        case .otherAccessibility: return "figure.wave"
        }
    }

    var symbolColor: Color {
        switch self {
        case .common: return .accentColor
        case .sleepSystem: return .orange
        case .finderSystem: return .secondary
        case .textEditing: return .blue
        case .accessibility, .otherAccessibility: return .secondary
        }
    }
}
