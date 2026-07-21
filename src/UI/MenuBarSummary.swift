import Foundation

enum MenuBarSummaryDisplayMode: String, CaseIterable, Equatable {
    case cost
    case tokens
    case costAndTokens
}

struct MenuBarSummarySnapshot: Equatable, Sendable {
    var totalCost: Decimal?
    var totalTokens: Int
    var sessionCount: Int
    var refreshedAt: Date?

    init(
        totalCost: Decimal?,
        totalTokens: Int,
        sessionCount: Int,
        refreshedAt: Date? = nil
    ) {
        self.totalCost = totalCost
        self.totalTokens = totalTokens
        self.sessionCount = sessionCount
        self.refreshedAt = refreshedAt
    }

    static let empty = MenuBarSummarySnapshot(
        totalCost: Decimal(0),
        totalTokens: 0,
        sessionCount: 0
    )
}

protocol MenuBarSummaryProviding {
    func currentSummary() throws -> MenuBarSummarySnapshot
}

protocol MenuBarSessionReading {
    func menuBarSessions() throws -> [NormalizedSession]
}

final class StorageBackedMenuBarSummaryProvider: MenuBarSummaryProviding {
    private let sessionReader: MenuBarSessionReading
    private let calendar: Calendar
    private let now: () -> Date

    init(
        sessionReader: MenuBarSessionReading,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.sessionReader = sessionReader
        self.calendar = calendar
        self.now = now
    }

    func currentSummary() throws -> MenuBarSummarySnapshot {
        let today = now()
        let sessions = try sessionReader.menuBarSessions().filter {
            calendar.isDate($0.startTime, inSameDayAs: today)
        }

        let tokenTotal = sessions.reduce(0) { total, session in
            total + (session.totalTokens ?? session.inputTokens ?? 0) + (session.totalTokens == nil ? (session.outputTokens ?? 0) : 0)
        }
        let costs = sessions.compactMap(\.estimatedCost)
        let costTotal = costs.isEmpty ? nil : costs.reduce(Decimal(0), +)

        return MenuBarSummarySnapshot(
            totalCost: costTotal,
            totalTokens: tokenTotal,
            sessionCount: sessions.count,
            refreshedAt: today
        )
    }
}

final class InMemoryMenuBarSummaryProvider: MenuBarSummaryProviding {
    var snapshot: MenuBarSummarySnapshot

    init(snapshot: MenuBarSummarySnapshot = .empty) {
        self.snapshot = snapshot
    }

    func currentSummary() throws -> MenuBarSummarySnapshot {
        snapshot
    }
}

extension InMemorySpendStorage: MenuBarSessionReading {
    func menuBarSessions() throws -> [NormalizedSession] {
        storedSessions()
    }
}
