import Foundation

struct PopoverDiagnostics: Equatable {
    var storageMode: String
    var databaseLocation: String?
    var pricingCatalogVersion: String
    var refreshSummary: String
    var refreshError: String?

    static let empty = PopoverDiagnostics(
        storageMode: "Unknown",
        databaseLocation: nil,
        pricingCatalogVersion: PricingCatalog.sourceVersion,
        refreshSummary: "No refresh yet",
        refreshError: nil
    )
}

struct PopoverDiagnosticsPresenter {
    func section(for diagnostics: PopoverDiagnostics) -> PopoverSectionRenderState {
        PopoverSectionRenderState(
            title: "Diagnostics",
            rows: rows(for: diagnostics),
            emptyText: "No diagnostics"
        )
    }

    private func rows(for diagnostics: PopoverDiagnostics) -> [PopoverRowRenderState] {
        [
            PopoverRowRenderState(
                title: "Refresh",
                detail: diagnostics.refreshError ?? diagnostics.refreshSummary,
                value: diagnostics.refreshError == nil ? "" : "Error"
            ),
            PopoverRowRenderState(
                title: "Storage",
                detail: diagnostics.databaseLocation ?? "Session data is not persisted",
                value: diagnostics.storageMode
            ),
            PopoverRowRenderState(
                title: "Pricing",
                detail: "Local catalog",
                value: diagnostics.pricingCatalogVersion
            )
        ]
    }
}
