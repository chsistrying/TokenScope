import Foundation

public struct NormalizedUsageBatch: Equatable, Sendable {
    public var sessions: [NormalizedSession]
    public var usageEvents: [UsageEvent]
    public var toolEvents: [ToolEvent]

    public var isEmpty: Bool {
        sessions.isEmpty && usageEvents.isEmpty && toolEvents.isEmpty
    }

    public init(
        sessions: [NormalizedSession] = [],
        usageEvents: [UsageEvent] = [],
        toolEvents: [ToolEvent] = []
    ) {
        self.sessions = sessions
        self.usageEvents = usageEvents
        self.toolEvents = toolEvents
    }
}

public protocol SpendStoring {
    func prepare() throws
    func upsert(_ batch: NormalizedUsageBatch) throws
}

public protocol SpendMaintenance {
    func clearAllData() throws
}

public struct SourceFileMetadata: Equatable, Sendable {
    public var modifiedAt: Date?
    public var byteSize: Int?

    public init(modifiedAt: Date? = nil, byteSize: Int? = nil) {
        self.modifiedAt = modifiedAt
        self.byteSize = byteSize
    }
}

public struct SourceFileIngestionState: Equatable, Sendable {
    public var provider: Provider
    public var path: String
    public var metadata: SourceFileMetadata
    public var contentHash: String
    public var lastIngestedAt: Date

    public init(
        provider: Provider,
        path: String,
        metadata: SourceFileMetadata,
        contentHash: String,
        lastIngestedAt: Date
    ) {
        self.provider = provider
        self.path = path
        self.metadata = metadata
        self.contentHash = contentHash
        self.lastIngestedAt = lastIngestedAt
    }
}

public protocol SourceFileIngestionIndex {
    func sourceFileState(provider: Provider, path: String) throws -> SourceFileIngestionState?
    func upsertSourceFileState(_ state: SourceFileIngestionState) throws
}

public extension SpendStoring {
    func save(sessions: [NormalizedSession], usageEvents: [UsageEvent]) throws {
        try upsert(NormalizedUsageBatch(sessions: sessions, usageEvents: usageEvents))
    }
}

public final class InMemorySpendStorage: SpendStoring, SpendMaintenance, SourceFileIngestionIndex {
    private var sessionsByID: [String: NormalizedSession]
    private var usageEventsByID: [String: UsageEvent]
    private var toolEventsByID: [String: ToolEvent]
    private var sourceFilesByKey: [String: SourceFileIngestionState]

    public init() {
        self.sessionsByID = [:]
        self.usageEventsByID = [:]
        self.toolEventsByID = [:]
        self.sourceFilesByKey = [:]
    }

    public func prepare() throws {
        sessionsByID = [:]
        usageEventsByID = [:]
        toolEventsByID = [:]
        sourceFilesByKey = [:]
    }

    public func clearAllData() throws {
        try prepare()
    }

    public func upsert(_ batch: NormalizedUsageBatch) throws {
        for session in batch.sessions {
            sessionsByID[session.id] = session
        }

        for usageEvent in batch.usageEvents {
            usageEventsByID[usageEvent.id] = usageEvent
        }

        for toolEvent in batch.toolEvents {
            toolEventsByID[toolEvent.id] = toolEvent
        }
    }

    public func storedSessions() -> [NormalizedSession] {
        sessionsByID.values.sorted { $0.id < $1.id }
    }

    public func storedUsageEvents() -> [UsageEvent] {
        usageEventsByID.values.sorted { $0.id < $1.id }
    }

    public func storedToolEvents() -> [ToolEvent] {
        toolEventsByID.values.sorted { $0.id < $1.id }
    }

    public func sourceFileState(provider: Provider, path: String) throws -> SourceFileIngestionState? {
        sourceFilesByKey[sourceFileKey(provider: provider, path: path)]
    }

    public func upsertSourceFileState(_ state: SourceFileIngestionState) throws {
        sourceFilesByKey[sourceFileKey(provider: state.provider, path: state.path)] = state
    }

    public func storedSourceFileStates() -> [SourceFileIngestionState] {
        sourceFilesByKey.values.sorted {
            if $0.provider.rawValue != $1.provider.rawValue {
                return $0.provider.rawValue < $1.provider.rawValue
            }

            return $0.path < $1.path
        }
    }

    private func sourceFileKey(provider: Provider, path: String) -> String {
        "\(provider.rawValue):\(path)"
    }
}
