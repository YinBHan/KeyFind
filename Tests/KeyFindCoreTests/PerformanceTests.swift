import XCTest
@testable import KeyFindCore

final class PerformanceTests: XCTestCase {
    private var shortcuts: [Shortcut]!

    override func setUpWithError() throws {
        shortcuts = try ShortcutCatalog().loadAll()
    }

    func testSearchPerformance() {
        let service = ShortcutSearchService(shortcuts: shortcuts)

        measure {
            _ = service.search("复制", limit: 5)
            _ = service.search("Chrome 打开新标签", limit: 5)
            _ = service.search("截图", limit: 5)
        }
    }

    func testCatalogLoadPerformance() {
        measure {
            do {
                _ = try ShortcutCatalog().loadAll()
            } catch {
                XCTFail("Failed to load the bundled shortcut catalog: \(error)")
            }
        }
    }
}
