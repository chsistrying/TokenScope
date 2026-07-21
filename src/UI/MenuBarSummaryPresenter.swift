import Foundation

struct MenuBarRenderState: Equatable {
    var statusTitle: String
    var menuItems: [MenuBarMenuItem]
}

enum MenuBarMenuItem: Equatable {
    case item(String)
    case separator
    case quit(String)
}

final class MenuBarSummaryPresenter {
    var displayMode: MenuBarSummaryDisplayMode

    private let summaryProvider: MenuBarSummaryProviding
    private let formatter: MenuBarSummaryFormatter

    init(
        displayMode: MenuBarSummaryDisplayMode = .cost,
        summaryProvider: MenuBarSummaryProviding,
        formatter: MenuBarSummaryFormatter = MenuBarSummaryFormatter()
    ) {
        self.displayMode = displayMode
        self.summaryProvider = summaryProvider
        self.formatter = formatter
    }

    func refresh() -> MenuBarRenderState {
        do {
            let snapshot = try summaryProvider.currentSummary()
            return render(snapshot)
        } catch {
            return MenuBarRenderState(
                statusTitle: "TokenScope",
                menuItems: [
                    .item("TokenScope"),
                    .separator,
                    .item("Summary unavailable"),
                    .separator,
                    .quit("Quit")
                ]
            )
        }
    }

    private func render(_ snapshot: MenuBarSummarySnapshot) -> MenuBarRenderState {
        MenuBarRenderState(
            statusTitle: formatter.statusTitle(for: snapshot, displayMode: displayMode),
            menuItems: [
                .item("TokenScope"),
                .separator,
                .item("Today Cost: \(formatter.menuCostText(snapshot.totalCost))"),
                .item("Today Tokens: \(formatter.menuTokensText(snapshot.totalTokens))"),
                .item("Sessions Today: \(formatter.menuSessionText(snapshot.sessionCount))"),
                .separator,
                .quit("Quit")
            ]
        )
    }
}

