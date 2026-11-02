import SwiftUI
import KeyFindCore

private extension Shortcut {
    var rowSymbolName: String {
        switch id {
        case "screen-full": return "photo"
        case "screen-area": return "rectangle.dashed"
        case "screen-toolbar": return "rectangle.inset.filled"
        case "copy": return "square.on.square"
        case "cut", "apple-171": return "scissors"
        case "paste", "apple-210": return "doc.on.clipboard"
        case "undo": return "arrow.uturn.backward"
        case "redo": return "arrow.uturn.forward"
        case "find", "apple-43": return "magnifyingglass"
        case "finder-move-here": return "folder.badge.arrow.right"
        case "force-quit": return "xmark.circle"
        case "apple-60", "apple-61", "apple-89": return "folder.badge.plus"
        case "apple-70", "apple-72": return "power"
        case "apple-104": return "link"
        case "apple-110", "apple-111": return "eye"
        case "apple-124", "apple-125": return "trash"
        case "voiceover": return "accessibility"
        case "invert-colors": return "circle.lefthalf.filled"
        default:
            if caution != nil { return "exclamationmark.triangle" }
            switch category {
            case .common: return "command.square"
            case .sleepSystem: return "power"
            case .finderSystem: return "folder"
            case .textEditing: return "textformat"
            case .accessibility, .otherAccessibility: return "accessibility"
            }
        }
    }

    var rowSymbolColor: Color {
        if caution != nil { return .orange }
        switch category {
        case .common: return .accentColor
        case .sleepSystem: return .orange
        case .finderSystem: return .secondary
        case .textEditing: return .secondary
        case .accessibility, .otherAccessibility: return .secondary
        }
    }
}

struct ShortcutRow: View {
    let shortcut: Shortcut
    let selected: Bool
    let favorite: Bool
    let copied: Bool
    let onCopy: () -> Void
    let onCopySymbol: () -> Void
    let onFavorite: () -> Void
    @State private var expanded = false

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: shortcut.rowSymbolName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 34, height: 34)
                .foregroundStyle(shortcut.rowSymbolColor)
                .background(shortcut.rowSymbolColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(shortcut.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        Text(shortcut.source.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
                Text(shortcut.caution ?? shortcut.description)
                    .font(.system(size: 10))
                    .foregroundStyle(shortcut.caution == nil ? Color.secondary : Color.orange)
                    .lineLimit(expanded ? nil : 1)
                if expanded, let steps = shortcut.steps, !steps.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 6)
            HStack(spacing: 3) {
                ForEach(shortcut.keys.modifiers + (shortcut.keys.key.isEmpty ? [] : [shortcut.keys.key]), id: \.self) { key in
                    Text(key).font(.system(size: 11, weight: .semibold, design: .monospaced)).frame(minWidth: 20).padding(.horizontal, 4).padding(.vertical, 4).background(.background.opacity(0.78), in: RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(.quaternary))
                }
            }
            Button(action: onFavorite) { Image(systemName: favorite ? "star.fill" : "star").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(favorite ? .orange : .secondary).help("收藏").opacity(selected ? 1 : 0.4)
            Button(action: onCopySymbol) { Image(systemName: "command").font(.system(size: 12)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("复制符号形式")
            Button(action: onCopy) {
                Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                    .font(.system(size: 12))
                    .foregroundStyle(copied ? Color.green : Color.secondary)
                    .scaleEffect(copied ? 1.18 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: copied)
            }
            .buttonStyle(.plain)
            .help("复制可读文本")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(selected ? Color.accentColor.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if shortcut.steps?.isEmpty == false {
                expanded.toggle()
            } else {
                onCopy()
            }
        }
    }
}
