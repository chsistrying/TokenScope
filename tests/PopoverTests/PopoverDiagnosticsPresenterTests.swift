import XCTest
@testable import TokenScope

final class PopoverDiagnosticsPresenterTests: XCTestCase {
    func testRendersRefreshStorageAndPricingDiagnostics() {
        let presenter = PopoverDiagnosticsPresenter()

        let section = presenter.section(for: PopoverDiagnostics(
            storageMode: "SQLite",
            databaseLocation: "/Users/example/Library/Application Support/TokenScope/TokenScope.sqlite3",
            pricingCatalogVersion: "2026-07-11",
            refreshSummary: "Discovered 5 · Parsed 1 · Unchanged 3 · Skipped 1",
            refreshError: nil
        ))

        XCTAssertEqual(section.title, "Diagnostics")
        XCTAssertEqual(section.rows, [
            PopoverRowRenderState(
                title: "Refresh",
                detail: "Discovered 5 · Parsed 1 · Unchanged 3 · Skipped 1",
                value: ""
            ),
            PopoverRowRenderState(
                title: "Storage",
                detail: "/Users/example/Library/Application Support/TokenScope/TokenScope.sqlite3",
                value: "SQLite"
            ),
            PopoverRowRenderState(
                title: "Pricing",
                detail: "Local catalog",
                value: "2026-07-11"
            )
        ])
    }

    func testRendersStorageFallbackAndRefreshError() {
        let presenter = PopoverDiagnosticsPresenter()

        let section = presenter.section(for: PopoverDiagnostics(
            storageMode: "In-memory fallback",
            databaseLocation: nil,
            pricingCatalogVersion: "2026-07-11",
            refreshSummary: "Discovered 0 · Parsed 0 · Unchanged 0 · Skipped 0",
            refreshError: "Refresh failed"
        ))

        XCTAssertEqual(section.rows, [
            PopoverRowRenderState(
                title: "Refresh",
                detail: "Refresh failed",
                value: "Error"
            ),
            PopoverRowRenderState(
                title: "Storage",
                detail: "Session data is not persisted",
                value: "In-memory fallback"
            ),
            PopoverRowRenderState(
                title: "Pricing",
                detail: "Local catalog",
                value: "2026-07-11"
            )
        ])
    }
}
