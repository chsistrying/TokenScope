import XCTest
@testable import TokenScope

final class PopoverMaintenancePresenterTests: XCTestCase {
    func testRendersRebuildRefreshCounts() {
        let presenter = PopoverMaintenancePresenter()

        let row = presenter.row(for: .rebuilt(LocalUsageIngestionResult(
            discoveredFileCount: 8,
            parsedFileCount: 3,
            importedSessionCount: 12,
            unchangedFileCount: 4,
            skippedFileCount: 1
        )))

        XCTAssertEqual(row, PopoverRowRenderState(
            title: "Database rebuilt",
            detail: "Discovered 8 · Parsed 3 · Unchanged 4 · Skipped 1",
            value: "12 imported"
        ))
    }

    func testRendersClearAndOpenResults() {
        let presenter = PopoverMaintenancePresenter()

        XCTAssertEqual(
            presenter.row(for: .cleared(removedSessionCount: 2)),
            PopoverRowRenderState(
                title: "Local data cleared",
                detail: "Removed 2 sessions and reset ingestion state",
                value: "Cleared"
            )
        )
        XCTAssertEqual(
            presenter.row(for: .openedDatabaseLocation(false)),
            PopoverRowRenderState(
                title: "No database location",
                detail: "Current storage is not persisted",
                value: "Unavailable"
            )
        )
    }
}
