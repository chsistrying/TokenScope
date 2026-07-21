import XCTest
@testable import TokenScope

final class ParserContractTests: XCTestCase {
    func testClaudeParserIdentifiesProvider() {
        let parser = ClaudeParser()

        XCTAssertEqual(parser.provider, .claude)
    }

    func testCodexParserIdentifiesProvider() {
        let parser = CodexParser()

        XCTAssertEqual(parser.provider, .codex)
    }

    func testClaudeParserMalformedInputThrowsDeterministically() {
        let parser = ClaudeParser()
        let input = ParserInput(sourcePath: "/placeholder/claude", contents: "ignored")

        XCTAssertThrowsError(try parser.parse(input)) { error in
            XCTAssertEqual(error as? ParserError, .unsupportedInput(provider: .claude, sourcePath: "/placeholder/claude"))
        }
    }

    func testCodexParserMalformedInputThrowsUnsupportedInputDeterministically() {
        let parser = CodexParser()
        let input = ParserInput(sourcePath: "/placeholder/codex", contents: "ignored")

        XCTAssertThrowsError(try parser.parse(input)) { error in
            XCTAssertEqual(error as? ParserError, .unsupportedInput(provider: .codex, sourcePath: input.sourcePath))
        }
    }

    func testParserInputCarriesPathAndOptionalContents() {
        let pathOnly = ParserInput(sourcePath: "/placeholder/log.jsonl")
        let withContents = ParserInput(sourcePath: "/placeholder/log.jsonl", contents: "{}")

        XCTAssertEqual(pathOnly.sourcePath, "/placeholder/log.jsonl")
        XCTAssertNil(pathOnly.contents)
        XCTAssertEqual(withContents.contents, "{}")
    }

    func testRawParserResultDefaultsToNoRecords() {
        let result = RawParserResult(provider: .claude, sourcePath: "/placeholder/log.jsonl")

        XCTAssertEqual(result.provider, .claude)
        XCTAssertEqual(result.sourcePath, "/placeholder/log.jsonl")
        XCTAssertEqual(result.records, [])
    }

    func testRawParserRecordCarriesPreNormalizationFields() {
        let startTime = Date(timeIntervalSince1970: 1_725_000_000)
        let endTime = Date(timeIntervalSince1970: 1_725_000_120)
        let record = RawParserRecord(
            model: "test-model",
            projectPath: "/Users/example/project",
            projectName: "project",
            providerSessionId: "provider-session-1",
            startTime: startTime,
            endTime: endTime,
            durationSeconds: 120,
            inputTokens: 100,
            outputTokens: 50,
            totalTokens: 150,
            rawSourcePath: "/placeholder/log.jsonl"
        )

        XCTAssertEqual(record.model, "test-model")
        XCTAssertEqual(record.projectPath, "/Users/example/project")
        XCTAssertEqual(record.projectName, "project")
        XCTAssertEqual(record.providerSessionId, "provider-session-1")
        XCTAssertEqual(record.startTime, startTime)
        XCTAssertEqual(record.endTime, endTime)
        XCTAssertEqual(record.durationSeconds, 120)
        XCTAssertEqual(record.inputTokens, 100)
        XCTAssertEqual(record.outputTokens, 50)
        XCTAssertEqual(record.totalTokens, 150)
        XCTAssertEqual(record.rawSourcePath, "/placeholder/log.jsonl")
    }

    func testParserErrorsAreExplicitAndEquatable() {
        XCTAssertEqual(
            ParserError.noData(provider: .codex, sourcePath: "/empty"),
            .noData(provider: .codex, sourcePath: "/empty")
        )
        XCTAssertEqual(
            ParserError.unsupportedInput(provider: .claude, sourcePath: "/unsupported"),
            .unsupportedInput(provider: .claude, sourcePath: "/unsupported")
        )
    }
}
