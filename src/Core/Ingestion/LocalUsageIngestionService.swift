import Foundation

public struct LocalUsageIngestionResult: Equatable, Sendable {
    public var discoveredFileCount: Int
    public var parsedFileCount: Int
    public var importedSessionCount: Int
    public var unchangedFileCount: Int
    public var skippedFileCount: Int

    public init(
        discoveredFileCount: Int = 0,
        parsedFileCount: Int = 0,
        importedSessionCount: Int = 0,
        unchangedFileCount: Int = 0,
        skippedFileCount: Int = 0
    ) {
        self.discoveredFileCount = discoveredFileCount
        self.parsedFileCount = parsedFileCount
        self.importedSessionCount = importedSessionCount
        self.unchangedFileCount = unchangedFileCount
        self.skippedFileCount = skippedFileCount
    }
}

public final class LocalUsageIngestionService {
    private let scanCandidates: () -> [CandidateSourceFile]
    private let parsersByProvider: [Provider: ProviderParsing]
    private let normalizer: UsageNormalizing
    private let storage: SpendStoring
    private let readContents: (String) throws -> String
    private let metadataForPath: (String) -> SourceFileMetadata?
    private let now: () -> Date

    public init(
        scanner: LocalLogScanner = LocalLogScanner(),
        parsers: [ProviderParsing] = [ClaudeParser(), CodexParser()],
        normalizer: UsageNormalizing,
        storage: SpendStoring,
        readContents: @escaping (String) throws -> String = {
            try String(contentsOfFile: $0, encoding: .utf8)
        },
        metadataForPath: @escaping (String) -> SourceFileMetadata? = LocalUsageIngestionService.defaultMetadata(for:),
        now: @escaping () -> Date = Date.init
    ) {
        self.scanCandidates = scanner.scan
        self.parsersByProvider = Dictionary(uniqueKeysWithValues: parsers.map { ($0.provider, $0) })
        self.normalizer = normalizer
        self.storage = storage
        self.readContents = readContents
        self.metadataForPath = metadataForPath
        self.now = now
    }

    init(
        scanCandidates: @escaping () -> [CandidateSourceFile],
        parsers: [ProviderParsing],
        normalizer: UsageNormalizing,
        storage: SpendStoring,
        readContents: @escaping (String) throws -> String,
        metadataForPath: @escaping (String) -> SourceFileMetadata? = LocalUsageIngestionService.defaultMetadata(for:),
        now: @escaping () -> Date = Date.init
    ) {
        self.scanCandidates = scanCandidates
        self.parsersByProvider = Dictionary(uniqueKeysWithValues: parsers.map { ($0.provider, $0) })
        self.normalizer = normalizer
        self.storage = storage
        self.readContents = readContents
        self.metadataForPath = metadataForPath
        self.now = now
    }

    public func ingest() throws -> LocalUsageIngestionResult {
        let candidates = scanCandidates()
        var result = LocalUsageIngestionResult(discoveredFileCount: candidates.count)
        var sessions: [NormalizedSession] = []
        var usageEvents: [UsageEvent] = []
        var toolEvents: [ToolEvent] = []
        var sourceFileStates: [SourceFileIngestionState] = []
        let ingestionIndex = storage as? SourceFileIngestionIndex

        for candidate in candidates {
            guard let parser = parsersByProvider[candidate.provider] else {
                result.skippedFileCount += 1
                continue
            }

            do {
                let metadata = metadataForPath(candidate.path)
                let existingState = try ingestionIndex?.sourceFileState(
                    provider: candidate.provider,
                    path: candidate.path
                )

                if let metadata, let existingState, Self.metadataMatches(existingState.metadata, metadata) {
                    result.unchangedFileCount += 1
                    continue
                }

                let contents = try readContents(candidate.path)
                let contentHash = Self.fnv1a64Hex(contents)

                if let existingState, existingState.contentHash == contentHash {
                    result.unchangedFileCount += 1
                    sourceFileStates.append(SourceFileIngestionState(
                        provider: candidate.provider,
                        path: candidate.path,
                        metadata: metadata ?? SourceFileMetadata(),
                        contentHash: contentHash,
                        lastIngestedAt: now()
                    ))
                    continue
                }

                let rawResult = try parser.parse(ParserInput(sourcePath: candidate.path, contents: contents))
                let normalizedBatch: NormalizedUsageBatch
                if let batchNormalizer = normalizer as? UsageBatchNormalizing {
                    normalizedBatch = try batchNormalizer.normalizeBatch(rawResult)
                } else {
                    normalizedBatch = NormalizedUsageBatch(sessions: try normalizer.normalize(rawResult))
                }

                result.parsedFileCount += 1
                result.importedSessionCount += normalizedBatch.sessions.count
                sessions.append(contentsOf: normalizedBatch.sessions)
                usageEvents.append(contentsOf: normalizedBatch.usageEvents)
                toolEvents.append(contentsOf: normalizedBatch.toolEvents)
                sourceFileStates.append(SourceFileIngestionState(
                    provider: candidate.provider,
                    path: candidate.path,
                    metadata: metadata ?? SourceFileMetadata(),
                    contentHash: contentHash,
                    lastIngestedAt: now()
                ))
            } catch {
                result.skippedFileCount += 1
            }
        }

        try storage.upsert(NormalizedUsageBatch(
            sessions: sessions,
            usageEvents: usageEvents,
            toolEvents: toolEvents
        ))
        for state in sourceFileStates {
            try ingestionIndex?.upsertSourceFileState(state)
        }
        return result
    }

    public static func defaultMetadata(for path: String) -> SourceFileMetadata? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }

        return SourceFileMetadata(
            modifiedAt: attributes[.modificationDate] as? Date,
            byteSize: (attributes[.size] as? NSNumber).map { Int(truncating: $0) }
        )
    }

    private static func metadataMatches(_ lhs: SourceFileMetadata, _ rhs: SourceFileMetadata) -> Bool {
        guard let lhsModifiedAt = lhs.modifiedAt,
              let rhsModifiedAt = rhs.modifiedAt,
              let lhsByteSize = lhs.byteSize,
              let rhsByteSize = rhs.byteSize else {
            return false
        }

        return abs(lhsModifiedAt.timeIntervalSince(rhsModifiedAt)) < 0.001 && lhsByteSize == rhsByteSize
    }

    private static func fnv1a64Hex(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3

        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }

        return String(format: "%016llx", hash)
    }
}
