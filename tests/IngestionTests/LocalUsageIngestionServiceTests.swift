import Foundation
import XCTest
@testable import TokenScope

final class LocalUsageIngestionServiceTests: XCTestCase {
    func testIngestScansParsesNormalizesAndStoresSessions() throws {
        let storage = InMemorySpendStorage()
        let service = LocalUsageIngestionService(
            scanCandidates: {
                [
                    CandidateSourceFile(provider: .claude, path: "/fixtures/claude/session.jsonl"),
                    CandidateSourceFile(provider: .codex, path: "/fixtures/codex/session.json")
                ]
            },
            parsers: [
                StubParser(provider: .claude),
                StubParser(provider: .codex)
            ],
            normalizer: StubNormalizer(),
            storage: storage,
            readContents: { "contents:\($0)" }
        )

        let result = try service.ingest()

        XCTAssertEqual(result, LocalUsageIngestionResult(
            discoveredFileCount: 2,
            parsedFileCount: 2,
            importedSessionCount: 2,
            skippedFileCount: 0
        ))
        XCTAssertEqual(storage.storedSessions().map(\.id), [
            "claude-/fixtures/claude/session.jsonl-0",
            "codex-/fixtures/codex/session.json-0"
        ])
    }

    func testIngestSkipsUnreadableOrMalformedFiles() throws {
        let storage = InMemorySpendStorage()
        let service = LocalUsageIngestionService(
            scanCandidates: {
                [
                    CandidateSourceFile(provider: .claude, path: "/ok.jsonl"),
                    CandidateSourceFile(provider: .claude, path: "/bad.jsonl")
                ]
            },
            parsers: [StubParser(provider: .claude)],
            normalizer: StubNormalizer(),
            storage: storage,
            readContents: {
                if $0 == "/bad.jsonl" {
                    throw TestError.unreadable
                }

                return "contents"
            }
        )

        let result = try service.ingest()

        XCTAssertEqual(result.discoveredFileCount, 2)
        XCTAssertEqual(result.parsedFileCount, 1)
        XCTAssertEqual(result.importedSessionCount, 1)
        XCTAssertEqual(result.skippedFileCount, 1)
        XCTAssertEqual(storage.storedSessions().map(\.id), ["claude-/ok.jsonl-0"])
    }

    func testIngestSkipsProvidersWithoutParser() throws {
        let storage = InMemorySpendStorage()
        let service = LocalUsageIngestionService(
            scanCandidates: {
                [CandidateSourceFile(provider: .codex, path: "/codex.json")]
            },
            parsers: [StubParser(provider: .claude)],
            normalizer: StubNormalizer(),
            storage: storage,
            readContents: { _ in "contents" }
        )

        let result = try service.ingest()

        XCTAssertEqual(result, LocalUsageIngestionResult(
            discoveredFileCount: 1,
            parsedFileCount: 0,
            importedSessionCount: 0,
            skippedFileCount: 1
        ))
        XCTAssertEqual(storage.storedSessions(), [])
    }

    func testIngestSkipsUnchangedFilesUsingStoredMetadata() throws {
        let storage = InMemorySpendStorage()
        let parser = CountingParser(provider: .claude)
        let modifiedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var readCount = 0
        let service = LocalUsageIngestionService(
            scanCandidates: {
                [CandidateSourceFile(provider: .claude, path: "/ok.jsonl")]
            },
            parsers: [parser],
            normalizer: StubNormalizer(),
            storage: storage,
            readContents: { _ in
                readCount += 1
                return "contents"
            },
            metadataForPath: { _ in
                SourceFileMetadata(modifiedAt: modifiedAt, byteSize: 8)
            },
            now: { Date(timeIntervalSince1970: 1_800_000_100) }
        )

        let firstResult = try service.ingest()
        let secondResult = try service.ingest()

        XCTAssertEqual(firstResult.parsedFileCount, 1)
        XCTAssertEqual(firstResult.unchangedFileCount, 0)
        XCTAssertEqual(secondResult.parsedFileCount, 0)
        XCTAssertEqual(secondResult.unchangedFileCount, 1)
        XCTAssertEqual(parser.parseCount, 1)
        XCTAssertEqual(readCount, 1)
    }

    func testIngestSkipsParsingWhenMetadataChangesButContentHashIsUnchanged() throws {
        let storage = InMemorySpendStorage()
        let parser = CountingParser(provider: .claude)
        var modifiedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let service = LocalUsageIngestionService(
            scanCandidates: {
                [CandidateSourceFile(provider: .claude, path: "/ok.jsonl")]
            },
            parsers: [parser],
            normalizer: StubNormalizer(),
            storage: storage,
            readContents: { _ in "same contents" },
            metadataForPath: { _ in
                SourceFileMetadata(modifiedAt: modifiedAt, byteSize: 13)
            }
        )

        _ = try service.ingest()
        modifiedAt = modifiedAt.addingTimeInterval(60)
        let secondResult = try service.ingest()

        XCTAssertEqual(secondResult.parsedFileCount, 0)
        XCTAssertEqual(secondResult.unchangedFileCount, 1)
        XCTAssertEqual(parser.parseCount, 1)
        XCTAssertEqual(storage.storedSourceFileStates().first?.metadata.modifiedAt, modifiedAt)
    }
}

private struct StubParser: ProviderParsing {
    var provider: Provider

    func parse(_ input: ParserInput) throws -> RawParserResult {
        RawParserResult(
            provider: provider,
            sourcePath: input.sourcePath,
            records: [
                RawParserRecord(
                    model: "test-model",
                    providerSessionId: "\(provider.rawValue)-session",
                    startTime: Date(timeIntervalSince1970: 1_800_000_000),
                    inputTokens: 10,
                    outputTokens: 5,
                    totalTokens: 15,
                    rawSourcePath: input.sourcePath
                )
            ]
        )
    }
}

private final class CountingParser: ProviderParsing {
    var provider: Provider
    private(set) var parseCount = 0

    init(provider: Provider) {
        self.provider = provider
    }

    func parse(_ input: ParserInput) throws -> RawParserResult {
        parseCount += 1
        return RawParserResult(
            provider: provider,
            sourcePath: input.sourcePath,
            records: [
                RawParserRecord(
                    model: "test-model",
                    providerSessionId: "\(provider.rawValue)-session",
                    startTime: Date(timeIntervalSince1970: 1_800_000_000),
                    inputTokens: 10,
                    outputTokens: 5,
                    totalTokens: 15,
                    rawSourcePath: input.sourcePath
                )
            ]
        )
    }
}

private struct StubNormalizer: UsageNormalizing {
    func normalize(_ result: ParserResult) throws -> [NormalizedSession] {
        result.records.enumerated().map { index, record in
            NormalizedSession(
                id: "\(result.provider.rawValue)-\(record.rawSourcePath)-\(index)",
                provider: result.provider,
                model: record.model ?? "unknown",
                projectPath: record.projectPath,
                projectName: record.projectName ?? "unknown",
                sessionId: record.providerSessionId ?? "unknown",
                startTime: record.startTime ?? Date(timeIntervalSince1970: 0),
                endTime: record.endTime,
                durationSeconds: record.durationSeconds,
                inputTokens: record.inputTokens,
                outputTokens: record.outputTokens,
                totalTokens: record.totalTokens,
                estimatedCost: nil,
                rawSourcePath: record.rawSourcePath
            )
        }
    }
}

private enum TestError: Error {
    case unreadable
}
