import Foundation

struct PopoverMaintenanceResult: Equatable {
    var title: String
    var detail: String
    var value: String

    static func refreshed(_ result: LocalUsageIngestionResult?) -> PopoverMaintenanceResult {
        PopoverMaintenanceResult(
            title: "Refreshed",
            detail: refreshDetail(result),
            value: importValue(result)
        )
    }

    static func rebuilt(_ result: LocalUsageIngestionResult?) -> PopoverMaintenanceResult {
        PopoverMaintenanceResult(
            title: "Database rebuilt",
            detail: refreshDetail(result),
            value: importValue(result)
        )
    }

    static func cleared(removedSessionCount: Int) -> PopoverMaintenanceResult {
        PopoverMaintenanceResult(
            title: "Local data cleared",
            detail: "Removed \(sessionText(removedSessionCount)) and reset ingestion state",
            value: "Cleared"
        )
    }

    static func openedDatabaseLocation(_ opened: Bool) -> PopoverMaintenanceResult {
        PopoverMaintenanceResult(
            title: opened ? "Database location opened" : "No database location",
            detail: opened ? "Finder is showing the active SQLite database" : "Current storage is not persisted",
            value: opened ? "Opened" : "Unavailable"
        )
    }

    static func failed(_ title: String) -> PopoverMaintenanceResult {
        PopoverMaintenanceResult(
            title: title,
            detail: "The database was not changed",
            value: "Error"
        )
    }

    static let unavailable = PopoverMaintenanceResult(
        title: "Maintenance unavailable",
        detail: "No maintenance action is connected",
        value: "Unavailable"
    )

    private static func refreshDetail(_ result: LocalUsageIngestionResult?) -> String {
        guard let result else {
            return "No refresh result"
        }

        return "Discovered \(result.discoveredFileCount) · Parsed \(result.parsedFileCount) · Unchanged \(result.unchangedFileCount) · Skipped \(result.skippedFileCount)"
    }

    private static func importValue(_ result: LocalUsageIngestionResult?) -> String {
        guard let result else {
            return "No result"
        }

        return "\(result.importedSessionCount) imported"
    }

    private static func sessionText(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
    }
}

struct PopoverMaintenancePresenter {
    func row(for result: PopoverMaintenanceResult) -> PopoverRowRenderState {
        PopoverRowRenderState(
            title: result.title,
            detail: result.detail,
            value: result.value
        )
    }
}

struct PopoverMaintenanceActions {
    var rebuildDatabase: () throws -> PopoverMaintenanceResult
    var clearLocalData: () throws -> PopoverMaintenanceResult
    var openDatabaseLocation: () -> PopoverMaintenanceResult

    static let disabled = PopoverMaintenanceActions(
        rebuildDatabase: { .unavailable },
        clearLocalData: { .unavailable },
        openDatabaseLocation: { .unavailable }
    )
}
