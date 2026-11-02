import Foundation

/// Shared dimensions and timing used by the native search interface.
enum UIConstants {
    enum Panel {
        static let width: CGFloat = 560
        static let minimumHeight: CGFloat = 103
        static let discoveryHeight: CGFloat = 178
        static let searchBarHeight: CGFloat = 64
        static let maxResultsHeight: CGFloat = 430
        static let verticalCenterOffset: CGFloat = 64
        static let contentChromeHeight: CGFloat = 84
        static let discoveryCompactHeight: CGFloat = 199
        static let discoveryRecentHeight: CGFloat = 262
        static let listPadding: CGFloat = 16
        static let moreButtonHeight: CGFloat = 48
    }

    enum Search {
        static let pageSize = 6
        static let recentSearchDisplayLimit = 4
    }

    enum Animation {
        static let copyFeedbackDuration: TimeInterval = 1.4
    }

    enum Typography {
        static let searchFieldSize: CGFloat = 19
        static let titleSize: CGFloat = 13
        static let descriptionSize: CGFloat = 10
        static let labelSize: CGFloat = 9
    }
}
