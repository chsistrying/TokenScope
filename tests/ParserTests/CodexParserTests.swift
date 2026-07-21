import XCTest
@testable import TokenScope

final class CodexParserTests: XCTestCase {
    func testParsesSanitizedCodexFixtureRecords() throws {
        let sourcePath = fixturePath("fixtures/codex/session-usage.json")
        let contents = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let parser = CodexParser()

        let result = try parser.parse(ParserInput(sourcePath: sourcePath, contents: contents))

        XCTAssertEqual(result.provider, .codex)
        XCTAssertEqual(result.sourcePath, sourcePath)
        XCTAssertEqual(result.records.count, 2)

        let first = try XCTUnwrap(result.records.first)
        XCTAssertEqual(first.model, "gpt-5-codex")
        XCTAssertEqual(first.providerSessionId, "codex-session-alpha")
        XCTAssertEqual(first.projectPath, "/Users/example/projects/alpha-app")
        XCTAssertEqual(first.projectName, "alpha-app")
        XCTAssertEqual(first.startTime, isoDate("2026-07-10T09:12:03Z"))
        XCTAssertEqual(first.endTime, isoDate("2026-07-10T09:18:45Z"))
        XCTAssertEqual(first.durationSeconds, 402)
        XCTAssertEqual(first.inputTokens, 1200)
        XCTAssertEqual(first.outputTokens, 340)
        XCTAssertEqual(first.totalTokens, 1540)
        XCTAssertEqual(first.rawSourcePath, sourcePath)

        let second = result.records[1]
        XCTAssertEqual(second.model, "gpt-5-codex-mini")
        XCTAssertEqual(second.providerSessionId, "codex-session-beta")
        XCTAssertEqual(second.projectPath, "/Users/example/projects/beta-tool")
        XCTAssertEqual(second.projectName, "beta-tool")
        XCTAssertEqual(second.startTime, isoDate("2026-07-10T10:00:00Z"))
        XCTAssertNil(second.endTime)
        XCTAssertNil(second.durationSeconds)
        XCTAssertEqual(second.inputTokens, 800)
        XCTAssertEqual(second.outputTokens, 220)
        XCTAssertEqual(second.totalTokens, 1020)
        XCTAssertEqual(second.rawSourcePath, sourcePath)
    }

    func testEmptyInputFailsDeterministically() {
        let parser = CodexParser()
        let input = ParserInput(sourcePath: "/fixtures/codex/empty.json", contents: "  \n")

        XCTAssertThrowsError(try parser.parse(input)) { error in
            XCTAssertEqual(error as? ParserError, .noData(provider: .codex, sourcePath: input.sourcePath))
        }
    }

    func testMalformedInputFailsDeterministically() {
        let parser = CodexParser()
        let input = ParserInput(sourcePath: "/fixtures/codex/malformed.json", contents: "{not-json")

        XCTAssertThrowsError(try parser.parse(input)) { error in
            XCTAssertEqual(error as? ParserError, .unsupportedInput(provider: .codex, sourcePath: input.sourcePath))
        }
    }

    func testEmptyRecordsFailDeterministically() {
        let parser = CodexParser()
        let input = ParserInput(sourcePath: "/fixtures/codex/no-records.json", contents: #"{"records":[]}"#)

        XCTAssertThrowsError(try parser.parse(input)) { error in
            XCTAssertEqual(error as? ParserError, .noData(provider: .codex, sourcePath: input.sourcePath))
        }
    }

    func testParsesCodexRolloutTokenCountSummary() throws {
        let parser = CodexParser()
        let sourcePath = "/Users/example/.codex/sessions/2026/07/10/rollout-test.jsonl"
        let fixture = """
        {"timestamp":"2026-07-10T10:00:00.000Z","type":"session_meta","payload":{"id":"rollout-test","session_id":"codex-session-real","cwd":"/Users/example/work/tokenscope"}}
        {"timestamp":"2026-07-10T10:00:01.000Z","type":"turn_context","payload":{"type":"turn_context","model":"gpt-5.5","cwd":"/Users/example/work/tokenscope"}}
        {"timestamp":"2026-07-10T10:00:20.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":20,"total_tokens":120}}}}
        {"timestamp":"2026-07-10T10:01:20.000Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":200,"cached_input_tokens":40,"output_tokens":30,"total_tokens":230}}}}
        """

        let result = try parser.parse(ParserInput(sourcePath: sourcePath, contents: fixture))

        XCTAssertEqual(result.provider, .codex)
        XCTAssertEqual(result.records.count, 1)

        let record = try XCTUnwrap(result.records.first)
        XCTAssertEqual(record.model, "gpt-5.5")
        XCTAssertEqual(record.providerSessionId, "codex-session-real")
        XCTAssertEqual(record.projectPath, "/Users/example/work/tokenscope")
        XCTAssertEqual(record.projectName, "tokenscope")
        XCTAssertEqual(record.startTime, isoDate("2026-07-10T10:01:20Z"))
        XCTAssertEqual(record.inputTokens, 200)
        XCTAssertEqual(record.cacheReadInputTokens, 40)
        XCTAssertEqual(record.outputTokens, 30)
        XCTAssertEqual(record.totalTokens, 230)
        XCTAssertEqual(record.rawSourcePath, sourcePath)
    }

    func testParsesCodexFixtureEdgeCasesWithCachedInputAndDerivedTotals() throws {
        let sourcePath = fixturePath("fixtures/codex/edge-cases.json")
        let contents = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let parser = CodexParser()

        let result = try parser.parse(ParserInput(sourcePath: sourcePath, contents: contents))

        let record = try XCTUnwrap(result.records.first)
        XCTAssertNil(record.model)
        XCTAssertNil(record.projectPath)
        XCTAssertNil(record.projectName)
        XCTAssertEqual(record.providerSessionId, "codex-fixture-edge")
        XCTAssertEqual(record.inputTokens, 200)
        XCTAssertEqual(record.cacheReadInputTokens, 75)
        XCTAssertEqual(record.outputTokens, 50)
        XCTAssertEqual(record.totalTokens, 250)
    }

    func testParsesCodexRolloutEdgeCasesAndSkipsMalformedPartialLines() throws {
        let sourcePath = fixturePath("fixtures/codex/rollout-edge-cases.jsonl")
        let contents = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let parser = CodexParser()

        let result = try parser.parse(ParserInput(sourcePath: sourcePath, contents: contents))

        let record = try XCTUnwrap(result.records.first)
        XCTAssertNil(record.model)
        XCTAssertEqual(record.projectPath, "/Users/example/work/edge-codex")
        XCTAssertEqual(record.projectName, "edge-codex")
        XCTAssertEqual(record.providerSessionId, "rollout-edge")
        XCTAssertEqual(record.inputTokens, 100)
        XCTAssertEqual(record.cacheReadInputTokens, 30)
        XCTAssertEqual(record.outputTokens, 20)
        XCTAssertNil(record.totalTokens)
    }

    func testParsesCodexRolloutToolEvents() throws {
        let sourcePath = fixturePath("fixtures/codex/rollout-tool-events.jsonl")
        let contents = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let parser = CodexParser()

        let result = try parser.parse(ParserInput(sourcePath: sourcePath, contents: contents))

        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.toolEvents.count, 2)

        let read = result.toolEvents[0]
        XCTAssertEqual(read.providerSessionId, "codex-tool-session")
        XCTAssertEqual(read.timestamp, isoDate("2026-07-10T10:00:10Z"))
        XCTAssertEqual(read.toolName, "Read")
        XCTAssertEqual(read.targetPath, "/Users/example/work/tokenscope/Sources/App.swift")
        XCTAssertNil(read.command)
        XCTAssertEqual(read.workingDirectory, "/Users/example/work/tokenscope")

        let exec = result.toolEvents[1]
        XCTAssertEqual(exec.providerSessionId, "codex-tool-session")
        XCTAssertEqual(exec.toolName, "exec_command")
        XCTAssertEqual(exec.toolCallId, "codex-tool-1")
        XCTAssertNil(exec.targetPath)
        XCTAssertEqual(exec.command, "sed -n '1,120p' Sources/App.swift")
        XCTAssertEqual(exec.workingDirectory, "/Users/example/work/tokenscope")
        XCTAssertEqual(exec.exitCode, 1)
        XCTAssertEqual(exec.errorSummary, "sed: Sources/App.swift: No such file or directory")
    }

    private func fixturePath(_ relativePath: String) -> String {
        FileManager.default.currentDirectoryPath + "/" + relativePath
    }

    private func isoDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
