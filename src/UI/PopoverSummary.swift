import Foundation

struct PopoverSummarySnapshot: Equatable, Sendable {
    var rangeTitle: String
    var totalCost: Decimal?
    var totalTokens: Int
    var sessionCount: Int
    var tokenPhases: [PopoverTokenPhase]
    var wasteSignals: [PopoverWasteSignal]
    var optimizationTips: [PopoverOptimizationTip] = []
    var sessionInsights: [PopoverSessionInsight]
    var sessionDetails: [PopoverSessionDetail] = []
    var providerSections: [PopoverProviderSection]
    var providerBreakdown: [PopoverBreakdownItem]
    var modelBreakdown: [PopoverBreakdownItem]
    var projectBreakdown: [PopoverBreakdownItem]
    var mostExpensiveSessions: [PopoverSessionItem]
    var timeline: [PopoverTimelineItem]
    var refreshedAt: Date?

    static let empty = PopoverSummarySnapshot(
        rangeTitle: "Today",
        totalCost: Decimal(0),
        totalTokens: 0,
        sessionCount: 0,
        tokenPhases: [],
        wasteSignals: [],
        optimizationTips: [],
        sessionInsights: [],
        providerSections: [],
        providerBreakdown: [],
        modelBreakdown: [],
        projectBreakdown: [],
        mostExpensiveSessions: [],
        timeline: []
    )
}

enum PopoverTimeRange: Equatable, Hashable, Sendable {
    case total
    case today
    case customLastDays(Int)

    var title: String {
        switch self {
        case .total:
            return "Total"
        case .today:
            return "Today"
        case .customLastDays(let days):
            return "\(days) days"
        }
    }
}

struct PopoverProviderSection: Equatable, Sendable {
    var providerName: String
    var cost: Decimal?
    var tokens: Int
    var sessionCount: Int
    var modelBreakdown: [PopoverBreakdownItem]
    var projectBreakdown: [PopoverBreakdownItem]
}

struct PopoverTokenPhase: Equatable, Sendable {
    var name: String
    var detail: String
    var tokens: Int
    var percentage: Int
}

struct PopoverWasteSignal: Equatable, Sendable {
    var title: String
    var detail: String
    var tokens: Int
    var valueText: String? = nil
}

struct PopoverSessionInsight: Equatable, Sendable {
    var detailID: String = ""
    var projectName: String
    var providerName: String
    var modelName: String
    var reason: String
    var recommendation: String
    var tokens: Int
    var cost: Decimal?
    var startTime: Date
    var valueText: String? = nil
}

struct PopoverSessionToolSignal: Equatable, Sendable {
    var title: String
    var detail: String
    var valueText: String
}

struct PopoverOptimizationTip: Equatable, Sendable {
    var title: String
    var detail: String
    var valueText: String
}

struct PopoverSessionDetail: Equatable, Sendable {
    var id: String
    var projectName: String
    var providerName: String
    var modelName: String
    var sessionId: String
    var cost: Decimal?
    var inputTokens: Int
    var cacheCreationInputTokens: Int
    var cacheReadInputTokens: Int
    var outputTokens: Int
    var totalTokens: Int
    var startTime: Date
    var endTime: Date?
    var durationSeconds: Int?
    var sourceDescription: String = "Local log"
    var reason: String
    var recommendation: String
    var toolSignals: [PopoverSessionToolSignal] = []
    var optimizationTips: [PopoverOptimizationTip] = []
}

struct PopoverBreakdownItem: Equatable, Sendable {
    var name: String
    var cost: Decimal?
    var tokens: Int
    var sessionCount: Int
}

struct PopoverSessionItem: Equatable, Sendable {
    var detailID: String = ""
    var providerName: String
    var modelName: String
    var projectName: String
    var cost: Decimal?
    var tokens: Int
    var startTime: Date
}

struct PopoverTimelineItem: Equatable, Sendable {
    var detailID: String = ""
    var providerName: String
    var modelName: String
    var projectName: String
    var cost: Decimal?
    var tokens: Int
    var startTime: Date
}

protocol PopoverSummaryProviding {
    func currentPopoverSummary(range: PopoverTimeRange) throws -> PopoverSummarySnapshot
}

protocol PopoverSessionReading {
    func popoverSessions() throws -> [NormalizedSession]
}

protocol PopoverToolEventReading {
    func popoverToolEvents() throws -> [ToolEvent]
}

final class StorageBackedPopoverSummaryProvider: PopoverSummaryProviding {
    private let sessionReader: PopoverSessionReading
    private let toolEventReader: PopoverToolEventReading?
    private let calendar: Calendar
    private let now: () -> Date
    private let expensiveSessionLimit: Int
    private let breakdownLimit: Int
    private let timelineLimit: Int

    init(
        sessionReader: PopoverSessionReading,
        toolEventReader: PopoverToolEventReading? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        expensiveSessionLimit: Int = 5,
        breakdownLimit: Int = 5,
        timelineLimit: Int = 5
    ) {
        self.sessionReader = sessionReader
        self.toolEventReader = toolEventReader
        self.calendar = calendar
        self.now = now
        self.expensiveSessionLimit = expensiveSessionLimit
        self.breakdownLimit = breakdownLimit
        self.timelineLimit = timelineLimit
    }

    func currentPopoverSummary(range: PopoverTimeRange) throws -> PopoverSummarySnapshot {
        let today = now()
        let sessions = try filteredSessions(range: range, now: today)
        let toolEvents = try filteredToolEvents(range: range, now: today)
        let displaySessions = aggregateDisplaySessions(sessions)
        let repeatedReads = repeatedReadSummaries(from: toolEvents)
        let repeatedSearches = repeatedSearchSummaries(from: toolEvents)
        let repeatedDirectoryListings = repeatedDirectoryListingSummaries(from: toolEvents)
        let repeatedFailedCommands = repeatedFailedCommandSummaries(from: toolEvents)

        let costs = sessions.compactMap(\.estimatedCost)
        let totalCost = costs.isEmpty ? nil : costs.reduce(Decimal(0), +)

        return PopoverSummarySnapshot(
            rangeTitle: range.title,
            totalCost: totalCost,
            totalTokens: sessions.reduce(0) { $0 + tokenCount(for: $1) },
            sessionCount: displaySessions.count,
            tokenPhases: tokenPhases(from: sessions),
            wasteSignals: wasteSignals(
                from: sessions,
                repeatedFailedCommands: repeatedFailedCommands,
                repeatedReads: repeatedReads,
                repeatedSearches: repeatedSearches,
                repeatedDirectoryListings: repeatedDirectoryListings
            ),
            optimizationTips: optimizationTips(
                sessions: sessions,
                repeatedFailedCommands: repeatedFailedCommands,
                repeatedReads: repeatedReads,
                repeatedSearches: repeatedSearches,
                repeatedDirectoryListings: repeatedDirectoryListings
            ),
            sessionInsights: sessionInsights(
                from: displaySessions,
                repeatedFailedCommands: repeatedFailedCommands,
                repeatedReads: repeatedReads,
                repeatedSearches: repeatedSearches,
                repeatedDirectoryListings: repeatedDirectoryListings
            ),
            sessionDetails: sessionDetails(
                from: displaySessions,
                repeatedFailedCommands: repeatedFailedCommands,
                repeatedReads: repeatedReads,
                repeatedSearches: repeatedSearches,
                repeatedDirectoryListings: repeatedDirectoryListings
            ),
            providerSections: providerSections(from: sessions),
            providerBreakdown: breakdown(
                sessions: sessions,
                key: { $0.provider.displayName }
            ),
            modelBreakdown: breakdown(
                sessions: sessions,
                key: { $0.model.isEmpty ? "Unknown model" : $0.model }
            ),
            projectBreakdown: breakdown(
                sessions: sessions,
                key: { $0.projectName.isEmpty ? "Unknown project" : $0.projectName }
            ),
            mostExpensiveSessions: mostExpensiveSessions(from: displaySessions),
            timeline: timeline(from: displaySessions),
            refreshedAt: today
        )
    }

    private func aggregateDisplaySessions(_ sessions: [NormalizedSession]) -> [NormalizedSession] {
        Dictionary(grouping: sessions, by: displaySessionKey)
            .map { _, sessions in
                let sortedSessions = sessions.sorted(by: compareTimelineSessions)
                let first = sortedSessions.first!
                let last = sortedSessions.last!
                let costs = sessions.compactMap(\.estimatedCost)

                return NormalizedSession(
                    id: displaySessionKey(for: first),
                    provider: first.provider,
                    model: first.model,
                    projectPath: first.projectPath,
                    projectName: first.projectName,
                    sessionId: first.sessionId,
                    startTime: sessions.map(\.startTime).max() ?? first.startTime,
                    endTime: sessions.compactMap(\.endTime).max(),
                    durationSeconds: sessions.compactMap(\.durationSeconds).reduce(0, +),
                    inputTokens: sumOptional(sessions.map(\.inputTokens)),
                    cacheCreationInputTokens: sumOptional(sessions.map(\.cacheCreationInputTokens)),
                    cacheReadInputTokens: sumOptional(sessions.map(\.cacheReadInputTokens)),
                    outputTokens: sumOptional(sessions.map(\.outputTokens)),
                    totalTokens: sessions.reduce(0) { $0 + tokenCount(for: $1) },
                    estimatedCost: costs.isEmpty ? nil : costs.reduce(Decimal(0), +),
                    rawSourcePath: last.rawSourcePath
                )
            }
    }

    private func displaySessionKey(for session: NormalizedSession) -> String {
        [
            session.provider.rawValue,
            session.sessionId,
            session.projectPath ?? session.projectName,
            session.model
        ].joined(separator: "\u{1F}")
    }

    private func sumOptional(_ values: [Int?]) -> Int? {
        let unwrapped = values.compactMap { $0 }
        guard !unwrapped.isEmpty else {
            return nil
        }

        return unwrapped.reduce(0, +)
    }

    private func filteredSessions(range: PopoverTimeRange, now: Date) throws -> [NormalizedSession] {
        let sessions = try sessionReader.popoverSessions()

        switch range {
        case .total:
            return sessions
        case .today:
            return sessions.filter {
                calendar.isDate($0.startTime, inSameDayAs: now)
            }
        case .customLastDays(let days):
            guard let start = calendar.date(byAdding: .day, value: -max(days - 1, 0), to: calendar.startOfDay(for: now)) else {
                return sessions
            }

            return sessions.filter { $0.startTime >= start && $0.startTime <= now }
        }
    }

    private func filteredToolEvents(range: PopoverTimeRange, now: Date) throws -> [ToolEvent] {
        let toolEvents = try toolEventReader?.popoverToolEvents() ?? []

        switch range {
        case .total:
            return toolEvents
        case .today:
            return toolEvents.filter {
                calendar.isDate($0.timestamp, inSameDayAs: now)
            }
        case .customLastDays(let days):
            guard let start = calendar.date(byAdding: .day, value: -max(days - 1, 0), to: calendar.startOfDay(for: now)) else {
                return toolEvents
            }

            return toolEvents.filter { $0.timestamp >= start && $0.timestamp <= now }
        }
    }

    private func providerSections(from sessions: [NormalizedSession]) -> [PopoverProviderSection] {
        Dictionary(grouping: sessions) { $0.provider.displayName }
            .map { providerName, sessions in
                let costs = sessions.compactMap(\.estimatedCost)

                return PopoverProviderSection(
                    providerName: providerName,
                    cost: costs.isEmpty ? nil : costs.reduce(Decimal(0), +),
                    tokens: sessions.reduce(0) { $0 + tokenCount(for: $1) },
                    sessionCount: sessions.count,
                    modelBreakdown: breakdown(
                        sessions: sessions,
                        key: { $0.model.isEmpty ? "Unknown model" : $0.model }
                    ),
                    projectBreakdown: breakdown(
                        sessions: sessions,
                        key: { $0.projectName.isEmpty ? "Unknown project" : $0.projectName }
                    )
                )
            }
            .sorted {
                if $0.cost != $1.cost {
                    return ($0.cost ?? -1) > ($1.cost ?? -1)
                }

                if $0.tokens != $1.tokens {
                    return $0.tokens > $1.tokens
                }

                return $0.providerName < $1.providerName
            }
    }

    private func tokenPhases(from sessions: [NormalizedSession]) -> [PopoverTokenPhase] {
        let baseInputTokenTotal = sessions.reduce(0) { $0 + baseInputTokens(for: $1) }
        let cacheCreationTokens = sessions.reduce(0) { $0 + ($1.cacheCreationInputTokens ?? 0) }
        let cacheReadTokens = sessions.reduce(0) { $0 + ($1.cacheReadInputTokens ?? 0) }
        let outputTokens = sessions.reduce(0) { $0 + ($1.outputTokens ?? 0) }
        let trackedTokens = baseInputTokenTotal + cacheCreationTokens + cacheReadTokens + outputTokens

        guard trackedTokens > 0 else {
            return []
        }

        return [
            PopoverTokenPhase(
                name: "Prompt/context",
                detail: "Base input, tools, files, and instructions",
                tokens: baseInputTokenTotal,
                percentage: percentage(baseInputTokenTotal, of: trackedTokens)
            ),
            PopoverTokenPhase(
                name: "Cache writes",
                detail: "New context prepared for reuse",
                tokens: cacheCreationTokens,
                percentage: percentage(cacheCreationTokens, of: trackedTokens)
            ),
            PopoverTokenPhase(
                name: "Cache reads",
                detail: "Previously cached context reused",
                tokens: cacheReadTokens,
                percentage: percentage(cacheReadTokens, of: trackedTokens)
            ),
            PopoverTokenPhase(
                name: "Output",
                detail: "Generated answer, code, and reasoning output",
                tokens: outputTokens,
                percentage: percentage(outputTokens, of: trackedTokens)
            )
        ].filter { $0.tokens > 0 }
    }

    private func wasteSignals(
        from sessions: [NormalizedSession],
        repeatedFailedCommands: [RepeatedFailedCommandSummary],
        repeatedReads: [RepeatedReadSummary],
        repeatedSearches: [RepeatedSearchSummary],
        repeatedDirectoryListings: [RepeatedDirectoryListingSummary]
    ) -> [PopoverWasteSignal] {
        guard !sessions.isEmpty
            || !repeatedFailedCommands.isEmpty
            || !repeatedReads.isEmpty
            || !repeatedSearches.isEmpty
            || !repeatedDirectoryListings.isEmpty else {
            return []
        }

        let behaviorSignals = repeatedFailedCommandSignals(from: repeatedFailedCommands)
            + repeatedReadSignals(from: repeatedReads)
            + repeatedSearchSignals(from: repeatedSearches)
            + repeatedDirectoryListingSignals(from: repeatedDirectoryListings)
        var tokenSignals: [PopoverWasteSignal] = []

        let inputHeavySessions = sessions.filter { session in
            let total = phaseTokenCount(for: session)
            guard total >= 10_000 else {
                return false
            }

            let inputLike = baseInputTokens(for: session)
                + (session.cacheCreationInputTokens ?? 0)
                + (session.cacheReadInputTokens ?? 0)
            return inputLike * 100 / max(total, 1) >= 80
        }
        if !inputHeavySessions.isEmpty {
            tokenSignals.append(PopoverWasteSignal(
                title: "Input-heavy sessions",
                detail: "\(inputHeavySessions.count) sessions dominated by prompt/context · Fix: trim carried context",
                tokens: inputHeavySessions.reduce(0) { $0 + phaseTokenCount(for: $1) }
            ))
        }

        let highCacheWriteTokens = sessions.reduce(0) { $0 + ($1.cacheCreationInputTokens ?? 0) }
        let trackedTokens = sessions.reduce(0) { $0 + phaseTokenCount(for: $1) }
        if highCacheWriteTokens >= 10_000 && highCacheWriteTokens * 100 / max(trackedTokens, 1) >= 20 {
            tokenSignals.append(PopoverWasteSignal(
                title: "High cache writes",
                detail: "Context is being recreated · Fix: keep reusable setup stable",
                tokens: highCacheWriteTokens
            ))
        }

        let largeSessions = sessions.filter { phaseTokenCount(for: $0) >= 100_000 }
        if !largeSessions.isEmpty {
            tokenSignals.append(PopoverWasteSignal(
                title: "Large sessions",
                detail: "\(largeSessions.count) sessions above 100k tokens · Fix: split work into passes",
                tokens: largeSessions.reduce(0) { $0 + phaseTokenCount(for: $1) }
            ))
        }

        let outputHeavySessions = sessions.filter { session in
            let total = phaseTokenCount(for: session)
            let output = session.outputTokens ?? 0
            return output >= 10_000 && output * 100 / max(total, 1) >= 50
        }
        if !outputHeavySessions.isEmpty {
            tokenSignals.append(PopoverWasteSignal(
                title: "Output-heavy sessions",
                detail: "\(outputHeavySessions.count) sessions generated large responses · Fix: ask for focused diffs",
                tokens: outputHeavySessions.reduce(0) { $0 + ($1.outputTokens ?? 0) }
            ))
        }

        let remainingLimit = max(0, 4 - behaviorSignals.count)
        return behaviorSignals + tokenSignals
            .sorted { $0.tokens > $1.tokens }
            .prefix(remainingLimit)
            .map { $0 }
    }

    private func repeatedReadSummaries(from toolEvents: [ToolEvent]) -> [RepeatedReadSummary] {
        let readsBySessionAndPath = Dictionary(grouping: toolEvents.compactMap { event -> RepeatedReadEvent? in
            guard let target = ToolEventReadClassifier.readTarget(for: event), !target.isEmpty else {
                return nil
            }

            return RepeatedReadEvent(
                sessionId: event.sessionId,
                providerName: event.provider.displayName,
                targetPath: target
            )
        }) { event in
            "\(event.sessionId)\u{1F}\(event.targetPath)"
        }

        return readsBySessionAndPath.values
            .filter { $0.count >= 3 }
            .compactMap { reads in
                guard let sample = reads.first else {
                    return nil
                }

                return RepeatedReadSummary(
                    sessionId: sample.sessionId,
                    providerName: sample.providerName,
                    targetPath: sample.targetPath,
                    count: reads.count
                )
            }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }

                return $0.targetPath < $1.targetPath
            }
    }

    private func repeatedReadSignals(from repeatedReads: [RepeatedReadSummary]) -> [PopoverWasteSignal] {
        guard let largest = repeatedReads.first else {
            return []
        }

        let detailPrefix = repeatedReads.count == 1
            ? "\(largest.fileName) read \(largest.count)x"
            : "\(largest.fileName) read \(largest.count)x; \(repeatedReads.count) repeated files"

        return [
            PopoverWasteSignal(
                title: "Repeated file reads",
                detail: "\(largest.providerName) · \(detailPrefix) · Fix: keep a file summary",
                tokens: 0,
                valueText: "\(largest.count)x"
            )
        ]
    }

    private func repeatedSearchSummaries(from toolEvents: [ToolEvent]) -> [RepeatedSearchSummary] {
        let searchesBySessionAndRoot = Dictionary(grouping: toolEvents.compactMap { event -> RepeatedSearchEvent? in
            guard let target = ToolEventSearchClassifier.searchTarget(for: event), !target.rootPath.isEmpty else {
                return nil
            }

            return RepeatedSearchEvent(
                sessionId: event.sessionId,
                providerName: event.provider.displayName,
                commandName: target.commandName,
                rootPath: target.rootPath
            )
        }) { event in
            "\(event.sessionId)\u{1F}\(event.commandName)\u{1F}\(event.rootPath)"
        }

        return searchesBySessionAndRoot.values
            .filter { $0.count >= 3 }
            .compactMap { searches in
                guard let sample = searches.first else {
                    return nil
                }

                return RepeatedSearchSummary(
                    sessionId: sample.sessionId,
                    providerName: sample.providerName,
                    commandName: sample.commandName,
                    rootPath: sample.rootPath,
                    count: searches.count
                )
            }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }

                return $0.rootPath < $1.rootPath
            }
    }

    private func repeatedSearchSignals(from repeatedSearches: [RepeatedSearchSummary]) -> [PopoverWasteSignal] {
        guard let largest = repeatedSearches.first else {
            return []
        }

        let detailPrefix = repeatedSearches.count == 1
            ? "\(largest.commandName) over \(largest.rootName) \(largest.count)x"
            : "\(largest.commandName) over \(largest.rootName) \(largest.count)x; \(repeatedSearches.count) repeated roots"

        return [
            PopoverWasteSignal(
                title: "Repeated broad searches",
                detail: "\(largest.providerName) · \(detailPrefix) · Fix: search exact files",
                tokens: 0,
                valueText: "\(largest.count)x"
            )
        ]
    }

    private func repeatedDirectoryListingSummaries(from toolEvents: [ToolEvent]) -> [RepeatedDirectoryListingSummary] {
        let listingsBySessionAndDirectory = Dictionary(grouping: toolEvents.compactMap { event -> RepeatedDirectoryListingEvent? in
            guard let target = ToolEventDirectoryListingClassifier.listingTarget(for: event), !target.directoryPath.isEmpty else {
                return nil
            }

            return RepeatedDirectoryListingEvent(
                sessionId: event.sessionId,
                providerName: event.provider.displayName,
                commandName: target.commandName,
                directoryPath: target.directoryPath
            )
        }) { event in
            "\(event.sessionId)\u{1F}\(event.directoryPath)"
        }

        return listingsBySessionAndDirectory.values
            .filter { $0.count >= 3 }
            .compactMap { listings in
                guard let sample = listings.first else {
                    return nil
                }

                return RepeatedDirectoryListingSummary(
                    sessionId: sample.sessionId,
                    providerName: sample.providerName,
                    commandName: sample.commandName,
                    directoryPath: sample.directoryPath,
                    count: listings.count
                )
            }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }

                return $0.directoryPath < $1.directoryPath
            }
    }

    private func repeatedDirectoryListingSignals(
        from repeatedDirectoryListings: [RepeatedDirectoryListingSummary]
    ) -> [PopoverWasteSignal] {
        guard let largest = repeatedDirectoryListings.first else {
            return []
        }

        let detailPrefix = repeatedDirectoryListings.count == 1
            ? "\(largest.commandName) over \(largest.directoryName) \(largest.count)x"
            : "\(largest.commandName) over \(largest.directoryName) \(largest.count)x; \(repeatedDirectoryListings.count) repeated folders"

        return [
            PopoverWasteSignal(
                title: "Repeated directory listings",
                detail: "\(largest.providerName) · \(detailPrefix) · Fix: reuse a directory map",
                tokens: 0,
                valueText: "\(largest.count)x"
            )
        ]
    }

    private func repeatedFailedCommandSummaries(from toolEvents: [ToolEvent]) -> [RepeatedFailedCommandSummary] {
        let failuresBySessionAndCommand = Dictionary(grouping: toolEvents.compactMap { event -> RepeatedFailedCommandEvent? in
            guard let target = ToolEventFailureClassifier.failureTarget(for: event) else {
                return nil
            }

            return RepeatedFailedCommandEvent(
                sessionId: event.sessionId,
                providerName: event.provider.displayName,
                commandName: target.commandName,
                commandKey: target.commandKey,
                errorSummary: target.errorSummary
            )
        }) { event in
            "\(event.sessionId)\u{1F}\(event.commandKey)"
        }

        return failuresBySessionAndCommand.values
            .filter { $0.count >= 2 }
            .compactMap { failures in
                guard let sample = failures.first else {
                    return nil
                }

                return RepeatedFailedCommandSummary(
                    sessionId: sample.sessionId,
                    providerName: sample.providerName,
                    commandName: sample.commandName,
                    commandKey: sample.commandKey,
                    errorSummary: sample.errorSummary,
                    count: failures.count
                )
            }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }

                return $0.commandKey < $1.commandKey
            }
    }

    private func repeatedFailedCommandSignals(
        from repeatedFailedCommands: [RepeatedFailedCommandSummary]
    ) -> [PopoverWasteSignal] {
        guard let largest = repeatedFailedCommands.first else {
            return []
        }

        let detailPrefix = repeatedFailedCommands.count == 1
            ? "\(largest.commandName) failed \(largest.count)x"
            : "\(largest.commandName) failed \(largest.count)x; \(repeatedFailedCommands.count) repeated failures"

        return [
            PopoverWasteSignal(
                title: "Repeated failed commands",
                detail: "\(largest.providerName) · \(detailPrefix) · Fix: inspect first error",
                tokens: 0,
                valueText: "\(largest.count)x"
            )
        ]
    }

    private func sessionInsights(
        from sessions: [NormalizedSession],
        repeatedFailedCommands: [RepeatedFailedCommandSummary],
        repeatedReads: [RepeatedReadSummary],
        repeatedSearches: [RepeatedSearchSummary],
        repeatedDirectoryListings: [RepeatedDirectoryListingSummary]
    ) -> [PopoverSessionInsight] {
        let tokenInsights = sessions.compactMap { session in
            insight(for: session)
        }

        let tokenInsightDetailIDs = Set(tokenInsights.map(\.detailID))
        let repeatedFailedCommandBySession = Dictionary(grouping: repeatedFailedCommands, by: \.sessionId)
        let repeatedReadBySession = Dictionary(grouping: repeatedReads, by: \.sessionId)
        let repeatedSearchBySession = Dictionary(grouping: repeatedSearches, by: \.sessionId)
        let repeatedDirectoryListingBySession = Dictionary(grouping: repeatedDirectoryListings, by: \.sessionId)
        let behaviorInsights = sessions.compactMap { session -> PopoverSessionInsight? in
            guard !tokenInsightDetailIDs.contains(session.id) else {
                return nil
            }

            let repeatedFailedCommand = repeatedFailedCommandBySession[session.sessionId]?.first
            let repeatedRead = repeatedReadBySession[session.sessionId]?.first
            let repeatedSearch = repeatedSearchBySession[session.sessionId]?.first
            let repeatedDirectoryListing = repeatedDirectoryListingBySession[session.sessionId]?.first
            let reason: String
            let recommendation: String
            let valueText: String

            if let repeatedFailedCommand {
                reason = "Repeated failed commands"
                recommendation = "\(repeatedFailedCommand.commandName) failed \(repeatedFailedCommand.count)x; inspect the error before retrying"
                valueText = "\(repeatedFailedCommand.count)x"
            } else if let repeatedRead {
                reason = "Repeated file reads"
                recommendation = "\(repeatedRead.fileName) read \(repeatedRead.count)x; keep stable files in context"
                valueText = "\(repeatedRead.count)x"
            } else if let repeatedSearch {
                reason = "Repeated broad searches"
                recommendation = "\(repeatedSearch.commandName) over \(repeatedSearch.rootName) \(repeatedSearch.count)x; narrow the search root"
                valueText = "\(repeatedSearch.count)x"
            } else if let repeatedDirectoryListing {
                reason = "Repeated directory listings"
                recommendation = "\(repeatedDirectoryListing.commandName) over \(repeatedDirectoryListing.directoryName) \(repeatedDirectoryListing.count)x; keep a brief directory map"
                valueText = "\(repeatedDirectoryListing.count)x"
            } else {
                return nil
            }

            return PopoverSessionInsight(
                detailID: session.id,
                projectName: session.projectName.isEmpty ? "Unknown project" : session.projectName,
                providerName: session.provider.displayName,
                modelName: session.model.isEmpty ? "Unknown model" : session.model,
                reason: reason,
                recommendation: recommendation,
                tokens: phaseTokenCount(for: session),
                cost: session.estimatedCost,
                startTime: session.startTime,
                valueText: valueText
            )
        }

        return (tokenInsights + behaviorInsights)
        .sorted {
            if $0.cost != $1.cost {
                return ($0.cost ?? -1) > ($1.cost ?? -1)
            }

            if $0.tokens != $1.tokens {
                return $0.tokens > $1.tokens
            }

            return $0.startTime > $1.startTime
        }
        .prefix(5)
        .map { $0 }
    }

    private func insight(for session: NormalizedSession) -> PopoverSessionInsight? {
        let total = phaseTokenCount(for: session)
        guard total >= 10_000 || session.estimatedCost != nil else {
            return nil
        }

        let signal = sessionSignal(for: session)

        return PopoverSessionInsight(
            detailID: session.id,
            projectName: session.projectName.isEmpty ? "Unknown project" : session.projectName,
            providerName: session.provider.displayName,
            modelName: session.model.isEmpty ? "Unknown model" : session.model,
            reason: signal.reason,
            recommendation: signal.recommendation,
            tokens: total,
            cost: session.estimatedCost,
            startTime: session.startTime
        )
    }

    private func sessionDetails(
        from sessions: [NormalizedSession],
        repeatedFailedCommands: [RepeatedFailedCommandSummary],
        repeatedReads: [RepeatedReadSummary],
        repeatedSearches: [RepeatedSearchSummary],
        repeatedDirectoryListings: [RepeatedDirectoryListingSummary]
    ) -> [PopoverSessionDetail] {
        let repeatedFailedCommandBySession = Dictionary(grouping: repeatedFailedCommands, by: \.sessionId)
        let repeatedReadBySession = Dictionary(grouping: repeatedReads, by: \.sessionId)
        let repeatedSearchBySession = Dictionary(grouping: repeatedSearches, by: \.sessionId)
        let repeatedDirectoryListingBySession = Dictionary(grouping: repeatedDirectoryListings, by: \.sessionId)

        return sessions
            .sorted {
                let lhsHasBehaviorSignal = repeatedFailedCommandBySession[$0.sessionId]?.isEmpty == false
                    || repeatedReadBySession[$0.sessionId]?.isEmpty == false
                    || repeatedSearchBySession[$0.sessionId]?.isEmpty == false
                    || repeatedDirectoryListingBySession[$0.sessionId]?.isEmpty == false
                let rhsHasBehaviorSignal = repeatedFailedCommandBySession[$1.sessionId]?.isEmpty == false
                    || repeatedReadBySession[$1.sessionId]?.isEmpty == false
                    || repeatedSearchBySession[$1.sessionId]?.isEmpty == false
                    || repeatedDirectoryListingBySession[$1.sessionId]?.isEmpty == false
                if lhsHasBehaviorSignal != rhsHasBehaviorSignal {
                    return lhsHasBehaviorSignal
                }

                if $0.estimatedCost != $1.estimatedCost {
                    return ($0.estimatedCost ?? -1) > ($1.estimatedCost ?? -1)
                }

                if phaseTokenCount(for: $0) != phaseTokenCount(for: $1) {
                    return phaseTokenCount(for: $0) > phaseTokenCount(for: $1)
                }

                return $0.startTime > $1.startTime
            }
            .prefix(10)
            .map { session in
                let signal = sessionSignal(for: session)

                return PopoverSessionDetail(
                    id: session.id,
                    projectName: session.projectName.isEmpty ? "Unknown project" : session.projectName,
                    providerName: session.provider.displayName,
                    modelName: session.model.isEmpty ? "Unknown model" : session.model,
                    sessionId: session.sessionId,
                    cost: session.estimatedCost,
                    inputTokens: baseInputTokens(for: session),
                    cacheCreationInputTokens: session.cacheCreationInputTokens ?? 0,
                    cacheReadInputTokens: session.cacheReadInputTokens ?? 0,
                    outputTokens: session.outputTokens ?? 0,
                    totalTokens: phaseTokenCount(for: session),
                    startTime: session.startTime,
                    endTime: session.endTime,
                    durationSeconds: session.durationSeconds,
                    sourceDescription: sourceDescription(for: session),
                    reason: signal.reason,
                    recommendation: signal.recommendation,
                    toolSignals: toolSignals(
                        repeatedFailedCommands: repeatedFailedCommandBySession[session.sessionId] ?? [],
                        repeatedReads: repeatedReadBySession[session.sessionId] ?? [],
                        repeatedSearches: repeatedSearchBySession[session.sessionId] ?? [],
                        repeatedDirectoryListings: repeatedDirectoryListingBySession[session.sessionId] ?? []
                    ),
                    optimizationTips: optimizationTips(
                        session: session,
                        repeatedFailedCommands: repeatedFailedCommandBySession[session.sessionId] ?? [],
                        repeatedReads: repeatedReadBySession[session.sessionId] ?? [],
                        repeatedSearches: repeatedSearchBySession[session.sessionId] ?? [],
                        repeatedDirectoryListings: repeatedDirectoryListingBySession[session.sessionId] ?? []
                    )
                )
            }
    }

    private func optimizationTips(
        sessions: [NormalizedSession],
        repeatedFailedCommands: [RepeatedFailedCommandSummary],
        repeatedReads: [RepeatedReadSummary],
        repeatedSearches: [RepeatedSearchSummary],
        repeatedDirectoryListings: [RepeatedDirectoryListingSummary]
    ) -> [PopoverOptimizationTip] {
        let behaviorTips = failedCommandOptimizationTips(from: repeatedFailedCommands)
            + repeatedReadOptimizationTips(from: repeatedReads)
            + repeatedSearchOptimizationTips(from: repeatedSearches)
            + directoryListingOptimizationTips(from: repeatedDirectoryListings)
        let tokenTips = sessions
            .sorted { phaseTokenCount(for: $0) > phaseTokenCount(for: $1) }
            .flatMap { tokenOptimizationTips(for: $0) }

        var seen: Set<String> = []
        return (behaviorTips + tokenTips).compactMap { tip in
            let key = "\(tip.title)\u{1F}\(tip.detail)"
            guard !seen.contains(key) else {
                return nil
            }

            seen.insert(key)
            return tip
        }
        .prefix(4)
        .map { $0 }
    }

    private func optimizationTips(
        session: NormalizedSession,
        repeatedFailedCommands: [RepeatedFailedCommandSummary],
        repeatedReads: [RepeatedReadSummary],
        repeatedSearches: [RepeatedSearchSummary],
        repeatedDirectoryListings: [RepeatedDirectoryListingSummary]
    ) -> [PopoverOptimizationTip] {
        let behaviorTips = failedCommandOptimizationTips(from: repeatedFailedCommands)
            + repeatedReadOptimizationTips(from: repeatedReads)
            + repeatedSearchOptimizationTips(from: repeatedSearches)
            + directoryListingOptimizationTips(from: repeatedDirectoryListings)
        let tokenTips = tokenOptimizationTips(for: session)

        return Array((behaviorTips + tokenTips).prefix(3))
    }

    private func failedCommandOptimizationTips(
        from repeatedFailedCommands: [RepeatedFailedCommandSummary]
    ) -> [PopoverOptimizationTip] {
        repeatedFailedCommands.prefix(1).map {
            PopoverOptimizationTip(
                title: "Stop retry loops",
                detail: "Read the first error, fix the command, then rerun once",
                valueText: "\($0.count)x"
            )
        }
    }

    private func repeatedReadOptimizationTips(from repeatedReads: [RepeatedReadSummary]) -> [PopoverOptimizationTip] {
        repeatedReads.prefix(1).map {
            PopoverOptimizationTip(
                title: "Avoid rereading stable files",
                detail: "Keep \($0.fileName) summary in context; ask for diffs only",
                valueText: "\($0.count)x"
            )
        }
    }

    private func repeatedSearchOptimizationTips(from repeatedSearches: [RepeatedSearchSummary]) -> [PopoverOptimizationTip] {
        repeatedSearches.prefix(1).map {
            PopoverOptimizationTip(
                title: "Narrow broad searches",
                detail: "Search exact files or symbols instead of \($0.rootName)",
                valueText: "\($0.count)x"
            )
        }
    }

    private func directoryListingOptimizationTips(
        from repeatedDirectoryListings: [RepeatedDirectoryListingSummary]
    ) -> [PopoverOptimizationTip] {
        repeatedDirectoryListings.prefix(1).map {
            PopoverOptimizationTip(
                title: "Reuse directory map",
                detail: "Keep a short map of \($0.directoryName); avoid listing it again",
                valueText: "\($0.count)x"
            )
        }
    }

    private func tokenOptimizationTips(for session: NormalizedSession) -> [PopoverOptimizationTip] {
        let total = phaseTokenCount(for: session)
        guard total > 0 else {
            return []
        }

        let promptTokens = baseInputTokens(for: session)
        let cacheCreationTokens = session.cacheCreationInputTokens ?? 0
        let cacheReadTokens = session.cacheReadInputTokens ?? 0
        let outputTokens = session.outputTokens ?? 0
        let inputLikeTokens = promptTokens + cacheCreationTokens + cacheReadTokens
        var tips: [PopoverOptimizationTip] = []

        if total >= 100_000 {
            tips.append(PopoverOptimizationTip(
                title: "Split the session",
                detail: "Run analysis, edit, and verification as separate passes",
                valueText: "Large"
            ))
        }

        if inputLikeTokens * 100 / max(total, 1) >= 80 {
            tips.append(PopoverOptimizationTip(
                title: "Trim carried context",
                detail: "Keep only current files, active errors, and recent decisions",
                valueText: "\(inputLikeTokens * 100 / max(total, 1))%"
            ))
        }

        if cacheCreationTokens >= 10_000 && cacheCreationTokens * 100 / max(total, 1) >= 20 {
            tips.append(PopoverOptimizationTip(
                title: "Stabilize reusable context",
                detail: "Keep setup text unchanged so cache reads replace cache writes",
                valueText: "\(cacheCreationTokens * 100 / max(total, 1))%"
            ))
        }

        if outputTokens >= 10_000 && outputTokens * 100 / max(total, 1) >= 50 {
            tips.append(PopoverOptimizationTip(
                title: "Cap generated output",
                detail: "Ask for patch summaries or one file instead of full dumps",
                valueText: "\(outputTokens * 100 / max(total, 1))%"
            ))
        }

        return tips
    }

    private func toolSignals(
        repeatedFailedCommands: [RepeatedFailedCommandSummary],
        repeatedReads: [RepeatedReadSummary],
        repeatedSearches: [RepeatedSearchSummary],
        repeatedDirectoryListings: [RepeatedDirectoryListingSummary]
    ) -> [PopoverSessionToolSignal] {
        let failedCommandSignals = repeatedFailedCommands.prefix(3).map {
            PopoverSessionToolSignal(
                title: "Repeated failed commands",
                detail: "\($0.commandName) failed \($0.count)x · \($0.errorSummary)",
                valueText: "\($0.count)x"
            )
        }
        let readSignals = repeatedReads.prefix(max(0, 3 - failedCommandSignals.count)).map {
            PopoverSessionToolSignal(
                title: "Repeated file reads",
                detail: "\($0.fileName) read \($0.count)x",
                valueText: "\($0.count)x"
            )
        }
        let searchSignals = repeatedSearches.prefix(max(0, 3 - failedCommandSignals.count - readSignals.count)).map {
            PopoverSessionToolSignal(
                title: "Repeated broad searches",
                detail: "\($0.commandName) over \($0.rootName) \($0.count)x",
                valueText: "\($0.count)x"
            )
        }
        let directorySignals = repeatedDirectoryListings.prefix(max(0, 3 - failedCommandSignals.count - readSignals.count - searchSignals.count)).map {
            PopoverSessionToolSignal(
                title: "Repeated directory listings",
                detail: "\($0.commandName) over \($0.directoryName) \($0.count)x",
                valueText: "\($0.count)x"
            )
        }

        return failedCommandSignals + readSignals + searchSignals + directorySignals
    }

    private func sourceDescription(for session: NormalizedSession) -> String {
        switch session.provider {
        case .claude:
            return "Claude local log"
        case .codex:
            return "Codex local log"
        }
    }

    private func sessionSignal(for session: NormalizedSession) -> (reason: String, recommendation: String) {
        let total = phaseTokenCount(for: session)
        let promptTokens = baseInputTokens(for: session)
        let cacheCreationTokens = session.cacheCreationInputTokens ?? 0
        let cacheReadTokens = session.cacheReadInputTokens ?? 0
        let outputTokens = session.outputTokens ?? 0
        let inputLikeTokens = promptTokens + cacheCreationTokens + cacheReadTokens

        if total >= 100_000 {
            return (
                "Large session over 100k tokens",
                "Split work into smaller passes and keep only current files in context"
            )
        } else if inputLikeTokens * 100 / max(total, 1) >= 80 {
            return (
                "Most tokens are prompt/context",
                "Trim repeated context, old logs, and broad file dumps before retrying"
            )
        } else if cacheCreationTokens >= 10_000 && cacheCreationTokens * 100 / max(total, 1) >= 20 {
            return (
                "High cache write cost",
                "Keep stable setup unchanged so cache can be reused across turns"
            )
        } else if outputTokens >= 10_000 && outputTokens * 100 / max(total, 1) >= 50 {
            return (
                "Large generated output",
                "Ask for focused diffs, summaries, or one file at a time"
            )
        } else if cacheReadTokens > promptTokens + outputTokens {
            return (
                "Cache dominates token volume",
                "Review whether the retained context is still needed for this task"
            )
        } else {
            return (
                "Notable cost session",
                "Check whether this work can be narrowed before the next run"
            )
        }
    }

    private func breakdown(
        sessions: [NormalizedSession],
        key: (NormalizedSession) -> String
    ) -> [PopoverBreakdownItem] {
        let grouped = Dictionary(grouping: sessions, by: key)

        return grouped.map { name, sessions in
            let costs = sessions.compactMap(\.estimatedCost)

            return PopoverBreakdownItem(
                name: name,
                cost: costs.isEmpty ? nil : costs.reduce(Decimal(0), +),
                tokens: sessions.reduce(0) { $0 + tokenCount(for: $1) },
                sessionCount: sessions.count
            )
        }
        .sorted(by: compareBreakdownItems)
        .prefix(breakdownLimit)
        .map { $0 }
    }

    private func mostExpensiveSessions(from sessions: [NormalizedSession]) -> [PopoverSessionItem] {
        sessions
            .filter { $0.estimatedCost != nil }
            .sorted {
                if $0.estimatedCost != $1.estimatedCost {
                    return ($0.estimatedCost ?? 0) > ($1.estimatedCost ?? 0)
                }

                return $0.startTime > $1.startTime
            }
            .prefix(expensiveSessionLimit)
            .map {
                PopoverSessionItem(
                    detailID: $0.id,
                    providerName: $0.provider.displayName,
                    modelName: $0.model.isEmpty ? "Unknown model" : $0.model,
                    projectName: $0.projectName.isEmpty ? "Unknown project" : $0.projectName,
                    cost: $0.estimatedCost,
                    tokens: tokenCount(for: $0),
                    startTime: $0.startTime
                )
            }
    }

    private func timeline(from sessions: [NormalizedSession]) -> [PopoverTimelineItem] {
        sessions
            .sorted(by: compareTimelineSessions)
            .prefix(timelineLimit)
            .map {
                PopoverTimelineItem(
                    detailID: $0.id,
                    providerName: $0.provider.displayName,
                    modelName: $0.model.isEmpty ? "Unknown model" : $0.model,
                    projectName: $0.projectName.isEmpty ? "Unknown project" : $0.projectName,
                    cost: $0.estimatedCost,
                    tokens: tokenCount(for: $0),
                    startTime: $0.startTime
                )
            }
    }

    private func compareTimelineSessions(_ lhs: NormalizedSession, _ rhs: NormalizedSession) -> Bool {
        if lhs.startTime != rhs.startTime {
            return lhs.startTime > rhs.startTime
        }

        let lhsKey = [
            lhs.provider.displayName,
            lhs.projectName,
            lhs.model,
            lhs.sessionId,
            lhs.id
        ]
        let rhsKey = [
            rhs.provider.displayName,
            rhs.projectName,
            rhs.model,
            rhs.sessionId,
            rhs.id
        ]

        return lhsKey.lexicographicallyPrecedes(rhsKey, by: <)
    }

    private func compareBreakdownItems(_ lhs: PopoverBreakdownItem, _ rhs: PopoverBreakdownItem) -> Bool {
        switch (lhs.cost, rhs.cost) {
        case let (left?, right?) where left != right:
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            if lhs.tokens != rhs.tokens {
                return lhs.tokens > rhs.tokens
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func tokenCount(for session: NormalizedSession) -> Int {
        if let totalTokens = session.totalTokens {
            return totalTokens
        }

        return (session.inputTokens ?? 0) + (session.outputTokens ?? 0)
    }

    private func phaseTokenCount(for session: NormalizedSession) -> Int {
        let phaseTokens = baseInputTokens(for: session)
            + (session.cacheCreationInputTokens ?? 0)
            + (session.cacheReadInputTokens ?? 0)
            + (session.outputTokens ?? 0)

        return phaseTokens > 0 ? phaseTokens : tokenCount(for: session)
    }

    private func baseInputTokens(for session: NormalizedSession) -> Int {
        let inputTokens = session.inputTokens ?? 0
        guard session.provider == .codex else {
            return inputTokens
        }

        return max(0, inputTokens - (session.cacheReadInputTokens ?? 0))
    }

    private func percentage(_ value: Int, of total: Int) -> Int {
        guard total > 0 else {
            return 0
        }

        return Int((Double(value) / Double(total) * 100).rounded())
    }
}

private struct RepeatedReadEvent {
    var sessionId: String
    var providerName: String
    var targetPath: String
}

private struct RepeatedSearchEvent {
    var sessionId: String
    var providerName: String
    var commandName: String
    var rootPath: String
}

private struct RepeatedDirectoryListingEvent {
    var sessionId: String
    var providerName: String
    var commandName: String
    var directoryPath: String
}

private struct RepeatedFailedCommandEvent {
    var sessionId: String
    var providerName: String
    var commandName: String
    var commandKey: String
    var errorSummary: String
}

private struct RepeatedReadSummary {
    var sessionId: String
    var providerName: String
    var targetPath: String
    var count: Int

    var fileName: String {
        URL(fileURLWithPath: targetPath).lastPathComponent
    }
}

private struct RepeatedSearchSummary {
    var sessionId: String
    var providerName: String
    var commandName: String
    var rootPath: String
    var count: Int

    var rootName: String {
        let lastPathComponent = URL(fileURLWithPath: rootPath).lastPathComponent
        return lastPathComponent.isEmpty ? rootPath : lastPathComponent
    }
}

private struct RepeatedDirectoryListingSummary {
    var sessionId: String
    var providerName: String
    var commandName: String
    var directoryPath: String
    var count: Int

    var directoryName: String {
        let lastPathComponent = URL(fileURLWithPath: directoryPath).lastPathComponent
        return lastPathComponent.isEmpty ? directoryPath : lastPathComponent
    }
}

private struct RepeatedFailedCommandSummary {
    var sessionId: String
    var providerName: String
    var commandName: String
    var commandKey: String
    var errorSummary: String
    var count: Int
}

final class InMemoryPopoverSummaryProvider: PopoverSummaryProviding {
    var snapshot: PopoverSummarySnapshot

    init(snapshot: PopoverSummarySnapshot = .empty) {
        self.snapshot = snapshot
    }

    func currentPopoverSummary() throws -> PopoverSummarySnapshot {
        snapshot
    }

    func currentPopoverSummary(range: PopoverTimeRange) throws -> PopoverSummarySnapshot {
        snapshot
    }
}

extension InMemorySpendStorage: PopoverSessionReading {
    func popoverSessions() throws -> [NormalizedSession] {
        storedSessions()
    }
}

extension InMemorySpendStorage: PopoverToolEventReading {
    func popoverToolEvents() throws -> [ToolEvent] {
        storedToolEvents()
    }
}
