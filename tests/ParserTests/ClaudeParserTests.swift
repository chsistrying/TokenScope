import XCTest
@testable import TokenScope

final class ClaudeParserTests: XCTestCase {
    func testParsesSanitizedClaudeUsageFixture() throws {
        let parser = ClaudeParser()
        let sourcePath = "/fixtures/claude/session-usage.jsonl"
        let fixture = """
        {"type":"usage","timestamp":"2026-01-15T10:00:00Z","end_time":"2026-01-15T10:02:10Z","duration_seconds":130,"session_id":"claude-session-001","model":"claude-3-5-sonnet-20241022","cwd":"/Users/example/work/tokenscope","project_name":"tokenscope","usage":{"input_tokens":1200,"output_tokens":340,"total_tokens":1540}}
        {"type":"usage","timestamp":"2026-01-15T10:05:00Z","session_id":"claude-session-001","model":"claude-3-5-sonnet-20241022","project_path":"/Users/example/work/tokenscope","project_name":"tokenscope","usage":{"input_tokens":600,"output_tokens":220}}
        """

        let result = try parser.parse(ParserInput(sourcePath: sourcePath, contents: fixture))

        XCTAssertEqual(result.provider, .claude)
        XCTAssertEqual(result.sourcePath, sourcePath)
        XCTAssertEqual(result.records.count, 2)

        let first = try XCTUnwrap(result.records.first)
        XCTAssertEqual(first.model, "claude-3-5-sonnet-20241022")
        XCTAssertEqual(first.providerSessionId, "claude-session-001")
        XCTAssertEqual(first.projectPath, "/Users/example/work/tokenscope")
        XCTAssertEqual(first.projectName, "tokenscope")
        XCTAssertEqual(first.inputTokens, 1200)
        XCTAssertEqual(first.outputTokens, 340)
        XCTAssertEqual(first.totalTokens, 1540)
        XCTAssertEqual(first.durationSeconds, 130)
        XCTAssertEqual(first.rawSourcePath, sourcePath)
        XCTAssertEqual(first.startTime, iso8601Date("2026-01-15T10:00:00Z"))
        XCTAssertEqual(first.endTime, iso8601Date("2026-01-15T10:02:10Z"))

        let second = result.records[1]
        XCTAssertEqual(second.inputTokens, 600)
        XCTAssertEqual(second.outputTokens, 220)
        XCTAssertEqual(second.totalTokens, 820)
        XCTAssertEqual(second.projectPath, "/Users/example/work/tokenscope")
        XCTAssertNil(second.endTime)
    }

    func testEmptyClaudeInputFailsDeterministically() {
        let parser = ClaudeParser()
        let input = ParserInput(sourcePath: "/fixtures/claude/empty.jsonl", contents: "\n\n")

        XCTAssertThrowsError(try parser.parse(input)) { error in
            XCTAssertEqual(error as? ParserError, .noData(provider: .claude, sourcePath: input.sourcePath))
        }
    }

    func testMalformedClaudeInputFailsDeterministically() {
        let parser = ClaudeParser()
        let input = ParserInput(sourcePath: "/fixtures/claude/malformed.jsonl", contents: "{not-json")

        XCTAssertThrowsError(try parser.parse(input)) { error in
            XCTAssertEqual(error as? ParserError, .unsupportedInput(provider: .claude, sourcePath: input.sourcePath))
        }
    }

    func testParsesClaudeTranscriptAssistantUsage() throws {
        let parser = ClaudeParser()
        let sourcePath = "/Users/example/.claude/projects/project/session.jsonl"
        let fixture = """
        {"type":"user","timestamp":"2026-07-10T10:00:00.000Z","sessionId":"claude-session-real","cwd":"/Users/example/work/tokenscope","message":{"role":"user","content":"hello"}}
        {"type":"assistant","timestamp":"2026-07-10T10:00:05.500Z","sessionId":"claude-session-real","cwd":"/Users/example/work/tokenscope","message":{"role":"assistant","model":"claude-sonnet-5","usage":{"input_tokens":2,"cache_creation_input_tokens":100,"cache_read_input_tokens":200,"output_tokens":50}}}
        """

        let result = try parser.parse(ParserInput(sourcePath: sourcePath, contents: fixture))

        XCTAssertEqual(result.provider, .claude)
        XCTAssertEqual(result.records.count, 1)

        let record = try XCTUnwrap(result.records.first)
        XCTAssertEqual(record.model, "claude-sonnet-5")
        XCTAssertEqual(record.providerSessionId, "claude-session-real")
        XCTAssertEqual(record.projectPath, "/Users/example/work/tokenscope")
        XCTAssertEqual(record.projectName, "tokenscope")
        XCTAssertEqual(record.startTime, iso8601Date("2026-07-10T10:00:05.500Z"))
        XCTAssertEqual(record.inputTokens, 2)
        XCTAssertEqual(record.cacheCreationInputTokens, 100)
        XCTAssertEqual(record.cacheReadInputTokens, 200)
        XCTAssertEqual(record.outputTokens, 50)
        XCTAssertEqual(record.totalTokens, 352)
        XCTAssertEqual(record.rawSourcePath, sourcePath)
    }

    func testParsesClaudeEdgeCasesAndSkipsMalformedPartialLines() throws {
        let sourcePath = fixturePath("fixtures/claude/edge-cases.jsonl")
        let contents = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let parser = ClaudeParser()

        let result = try parser.parse(ParserInput(sourcePath: sourcePath, contents: contents))

        XCTAssertEqual(result.records.count, 2)

        let transcriptRecord = result.records[0]
        XCTAssertNil(transcriptRecord.model)
        XCTAssertEqual(transcriptRecord.projectPath, "/Users/example/work/edge-app")
        XCTAssertEqual(transcriptRecord.projectName, "edge-app")
        XCTAssertEqual(transcriptRecord.providerSessionId, "claude-edge")
        XCTAssertEqual(transcriptRecord.inputTokens, 10)
        XCTAssertEqual(transcriptRecord.cacheCreationInputTokens, 20)
        XCTAssertEqual(transcriptRecord.cacheReadInputTokens, 30)
        XCTAssertEqual(transcriptRecord.outputTokens, 5)
        XCTAssertEqual(transcriptRecord.totalTokens, 65)

        let fixtureRecord = result.records[1]
        XCTAssertNil(fixtureRecord.model)
        XCTAssertEqual(fixtureRecord.projectPath, "/Users/example/work/fixture-edge")
        XCTAssertNil(fixtureRecord.projectName)
        XCTAssertEqual(fixtureRecord.providerSessionId, "claude-fixture-edge")
        XCTAssertEqual(fixtureRecord.inputTokens, 40)
        XCTAssertEqual(fixtureRecord.cacheCreationInputTokens, 50)
        XCTAssertEqual(fixtureRecord.cacheReadInputTokens, 60)
        XCTAssertEqual(fixtureRecord.outputTokens, 7)
        XCTAssertEqual(fixtureRecord.totalTokens, 157)
    }

    func testParsesClaudeToolUseEvents() throws {
        let sourcePath = fixturePath("fixtures/claude/tool-events.jsonl")
        let contents = try String(contentsOfFile: sourcePath, encoding: .utf8)
        let parser = ClaudeParser()

        let result = try parser.parse(ParserInput(sourcePath: sourcePath, contents: contents))

        XCTAssertEqual(result.records.count, 1)
        XCTAssertEqual(result.toolEvents.count, 2)

        let read = result.toolEvents[0]
        XCTAssertEqual(read.providerSessionId, "claude-tool-session")
        XCTAssertEqual(read.timestamp, iso8601Date("2026-07-10T10:00:05.500Z"))
        XCTAssertEqual(read.toolName, "Read")
        XCTAssertEqual(read.toolCallId, "tool-read-1")
        XCTAssertEqual(read.targetPath, "/Users/example/work/tokenscope/Sources/App.swift")
        XCTAssertNil(read.command)
        XCTAssertNil(read.exitCode)
        XCTAssertEqual(read.workingDirectory, "/Users/example/work/tokenscope")
        XCTAssertEqual(read.rawSourcePath, sourcePath)

        let bash = result.toolEvents[1]
        XCTAssertEqual(bash.toolName, "Bash")
        XCTAssertEqual(bash.toolCallId, "tool-bash-1")
        XCTAssertNil(bash.targetPath)
        XCTAssertEqual(bash.command, "sed -n '1,120p' Sources/App.swift")
        XCTAssertEqual(bash.workingDirectory, "/Users/example/work/tokenscope")
        XCTAssertEqual(bash.exitCode, 1)
        XCTAssertEqual(bash.errorSummary, "sed: Sources/App.swift: No such file or directory")
    }

    private func iso8601Date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func fixturePath(_ relativePath: String) -> String {
        FileManager.default.currentDirectoryPath + "/" + relativePath
    }
}
