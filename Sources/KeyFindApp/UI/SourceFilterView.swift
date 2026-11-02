import SwiftUI
import KeyFindCore

struct SourceFilterView: View {
    let sources: [ShortcutSource]
    let selectedSource: ShortcutSource?
    let onSelect: (ShortcutSource?) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                Text("来源")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                SourceFilterChip(title: "全部", icon: "square.grid.2x2", selected: selectedSource == nil) {
                    onSelect(nil)
                }
                ForEach(sources, id: \.self) { source in
                    SourceFilterChip(title: source.displayName, icon: sourceIcon(for: source), selected: selectedSource == source) {
                        onSelect(source)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 16)
    }

    private func sourceIcon(for source: ShortcutSource) -> String {
        switch source {
        case .system: return "apple.logo"
        case .app(.finder): return "folder"
        case .app(.safari): return "safari"
        case .app(.chrome): return "globe"
        case .app(.vscode): return "chevron.left.forwardslash.chevron.right"
        case .app(.chatgpt): return "bubble.left.and.bubble.right"
        case .app(.terminal): return "terminal"
        case .app(.xcode): return "hammer"
        case .app(.figma): return "pencil.and.ruler"
        case .app(.notion): return "doc.text"
        case .app(.raycast): return "bolt"
        }
    }
}

private struct SourceFilterChip: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: selected ? .semibold : .regular))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.055), in: Capsule())
        .overlay(Capsule().stroke(selected ? Color.accentColor.opacity(0.24) : Color.primary.opacity(0.07)))
    }
}

