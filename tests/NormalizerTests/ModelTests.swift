import XCTest
@testable import TokenScope

final class ModelTests: XCTestCase {
    func testProviderRawIDs() {
        XCTAssertEqual(Provider.claude.rawValue, "claude")
        XCTAssertEqual(Provider.codex.rawValue, "codex")
    }

    func testProviderDisplayNames() {
        XCTAssertEqual(Provider.claude.displayName, "Claude")
        XCTAssertEqual(Provider.codex.displayName, "Codex")
    }

    func testProviderCodingUsesRawID() throws {
        XCTAssertEqual(try roundTrip(Provider.claude), .claude)
        XCTAssertEqual(try roundTrip(Provider.codex), .codex)
    }

    func testNormalizedSessionEqualityAndCoding() throws {
        let session = NormalizedSession(
            id: "session-record-1",
            provider: .claude,
            model: "claude-test-model",
            projectPath: "/Users/example/project",
            projectName: "project",
            sessionId: "provider-session-1",
            startTime: Date(timeIntervalSince1970: 1_725_000_000),
            endTime: Date(timeIntervalSince1970: 1_725_000_120),
            durationSeconds: 120,
            inputTokens: 100,
            outputTokens: 50,
            totalTokens: 150,
            estimatedCost: Decimal(string: "0.0123"),
            rawSourcePath: "/Users/example/.claude/log.jsonl"
        )

        XCTAssertEqual(session, session)
        XCTAssertEqual(try roundTrip(session), session)
    }

    func testUsageEventEqualityAndCoding() throws {
        let event = UsageEvent(
            id: "event-1",
            sessionId: "session-record-1",
            timestamp: Date(timeIntervalSince1970: 1_725_000_060),
            inputTokens: 25,
            outputTokens: 10,
            totalTokens: 35,
            estimatedCost: nil,
            rawSourcePath: "/Users/example/.codex/history.jsonl"
        )

        XCTAssertEqual(event, event)
        XCTAssertEqual(try roundTrip(event), event)
    }

    func testToolEventEqualityAndCoding() throws {
        let event = ToolEvent(
            id: "tool-event-1",
            provider: .claude,
            sessionId: "session-record-1",
            timestamp: Date(timeIntervalSince1970: 1_725_000_060),
            toolName: "Read",
            targetPath: "/Users/example/project/App.swift",
            command: nil,
            rawSourcePath: "/Users/example/.claude/log.jsonl"
        )

        XCTAssertEqual(event, event)
        XCTAssertEqual(try roundTrip(event), event)
    }

    func testProjectEqualityAndCoding() throws {
        let project = Project(
            id: "project-1",
            name: "project",
            path: "/Users/example/project"
        )

        XCTAssertEqual(project, project)
        XCTAssertEqual(try roundTrip(project), project)
    }

    func testNormalizerReturnsNoSessionsForEmptyInput() throws {
        let normalizer = RawUsageNormalizer()
        let result = ParserResult(provider: .claude, sourcePath: "/placeholder")

        XCTAssertEqual(try normalizer.normalize(result), [])
    }

    func testRawUsageNormalizerProducesDeterministicIDs() throws {
        let normalizer = RawUsageNormalizer()
        let result = ParserResult(
            provider: .codex,
            sourcePath: "/Users/example/.codex/history.jsonl",
            records: [
                RawParserRecord(
                    model: "gpt-5-codex",
                    providerSessionId: "provider-session-1",
                    startTime: Date(timeIntervalSince1970: 1_725_000_000),
                    rawSourcePath: "/Users/example/.codex/history.jsonl"
                ),
                RawParserRecord(
                    model: "gpt-5-codex",
                    providerSessionId: "provider-session-1",
                    startTime: Date(timeIntervalSince1970: 1_725_000_000),
                    rawSourcePath: "/Users/example/.codex/history.jsonl"
                )
            ]
        )

        let firstRun = try normalizer.normalize(result)
        let secondRun = try normalizer.normalize(result)

        XCTAssertEqual(firstRun.map(\.id), secondRun.map(\.id))
        XCTAssertEqual(firstRun[0].id, "normalized-session-bf402c7430b88904")
        XCTAssertEqual(firstRun[1].id, "normalized-session-bf402d7430b88ab7")
        XCTAssertNotEqual(firstRun[0].id, firstRun[1].id)
    }

    func testRawUsageNormalizerUsesProjectNameFallbackFromPath() throws {
        let normalizer = RawUsageNormalizer()
        let result = ParserResult(
            provider: .claude,
            sourcePath: "/source",
            records: [
                RawParserRecord(
                    projectPath: "/Users/example/work/token-scope",
                    rawSourcePath: "/raw"
                )
            ]
        )

        let sessions = try normalizer.normalize(result)

        XCTAssertEqual(sessions.single?.projectName, "token-scope")
        XCTAssertEqual(sessions.single?.projectPath, "/Users/example/work/token-scope")
    }

    func testRawUsageNormalizerDerivesTotalTokensWhenMissing() throws {
        let normalizer = RawUsageNormalizer()
        let result = ParserResult(
            provider: .claude,
            sourcePath: "/source",
            records: [
                RawParserRecord(
                    inputTokens: 120,
                    outputTokens: 45,
                    rawSourcePath: "/raw"
                ),
                RawParserRecord(
                    inputTokens: 120,
                    outputTokens: 45,
                    totalTokens: 200,
                    rawSourcePath: "/raw"
                )
            ]
        )

        let sessions = try normalizer.normalize(result)

        XCTAssertEqual(sessions[0].totalTokens, 165)
        XCTAssertEqual(sessions[1].totalTokens, 200)
    }

    func testRawUsageNormalizerUsesUnknownAndStableFallbacks() throws {
        let normalizer = RawUsageNormalizer()
        let result = ParserResult(
            provider: .codex,
            sourcePath: "/source",
            records: [
                RawParserRecord(rawSourcePath: "/raw/missing-fields.jsonl")
            ]
        )

        let session = try XCTUnwrap(try normalizer.normalize(result).single)

        XCTAssertEqual(session.provider, .codex)
        XCTAssertEqual(session.model, "unknown")
        XCTAssertNil(session.projectPath)
        XCTAssertEqual(session.projectName, "unknown")
        XCTAssertEqual(session.sessionId, "generated-session-84be0a7eaf3adad0")
        XCTAssertEqual(session.startTime, Date(timeIntervalSince1970: 0))
        XCTAssertNil(session.endTime)
        XCTAssertNil(session.durationSeconds)
        XCTAssertNil(session.inputTokens)
        XCTAssertNil(session.outputTokens)
        XCTAssertNil(session.totalTokens)
        XCTAssertNil(session.estimatedCost)
        XCTAssertEqual(session.rawSourcePath, "/raw/missing-fields.jsonl")
    }

    func testRawUsageNormalizerReturnsEmptyResults() throws {
        let normalizer = RawUsageNormalizer()
        let result = ParserResult(provider: .codex, sourcePath: "/empty", records: [])

        XCTAssertEqual(try normalizer.normalize(result), [])
    }

    func testRawUsageNormalizerNormalizesToolEventsInBatch() throws {
        let normalizer = RawUsageNormalizer()
        let result = ParserResult(
            provider: .claude,
            sourcePath: "/source",
            toolEvents: [
                RawToolEvent(
                    providerSessionId: "provider-session-1",
                    timestamp: Date(timeIntervalSince1970: 1_725_000_060),
                    toolName: "Read",
                    targetPath: "/Users/example/project/App.swift",
                    workingDirectory: "/Users/example/project",
                    rawSourcePath: "/raw"
                )
            ]
        )

        let batch = try normalizer.normalizeBatch(result)

        XCTAssertEqual(batch.sessions, [])
        let event = try XCTUnwrap(batch.toolEvents.single)
        XCTAssertEqual(event.provider, .claude)
        XCTAssertEqual(event.sessionId, "provider-session-1")
        XCTAssertEqual(event.timestamp, Date(timeIntervalSince1970: 1_725_000_060))
        XCTAssertEqual(event.toolName, "Read")
        XCTAssertEqual(event.targetPath, "/Users/example/project/App.swift")
        XCTAssertEqual(event.workingDirectory, "/Users/example/project")
        XCTAssertEqual(event.rawSourcePath, "/raw")
        XCTAssertEqual(event.id, "tool-event-5900def5bdcc54b5")
    }

    private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(value)
        return try decoder.decode(Value.self, from: data)
    }
}

private extension Array {
    var single: Element? {
        count == 1 ? self[0] : nil
    }
}
