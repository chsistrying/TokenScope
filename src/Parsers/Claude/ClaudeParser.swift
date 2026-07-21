import Foundation

public struct ClaudeParser: ProviderParsing {
    public let provider: Provider = .claude

    public init() {}

    public func parse(_ input: ParserInput) throws -> RawParserResult {
        guard let contents = input.contents else {
            throw ParserError.unsupportedInput(provider: provider, sourcePath: input.sourcePath)
        }

        let lines = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            throw ParserError.noData(provider: provider, sourcePath: input.sourcePath)
        }

        var records: [RawParserRecord] = []
        var toolEvents: [RawToolEvent] = []
        var toolEventIndexesByCallId: [String: Int] = [:]
        var sawUnsupportedLine = false

        for line in lines {
            do {
                if let record = try parseRecord(line, sourcePath: input.sourcePath) {
                    records.append(record)
                }
                try parseToolEvents(
                    line,
                    sourcePath: input.sourcePath,
                    toolEvents: &toolEvents,
                    toolEventIndexesByCallId: &toolEventIndexesByCallId
                )
            } catch ParserError.unsupportedInput {
                sawUnsupportedLine = true
            }
        }

        guard !records.isEmpty || !toolEvents.isEmpty else {
            if sawUnsupportedLine {
                throw ParserError.unsupportedInput(provider: provider, sourcePath: input.sourcePath)
            }

            throw ParserError.noData(provider: provider, sourcePath: input.sourcePath)
        }

        return RawParserResult(
            provider: provider,
            sourcePath: input.sourcePath,
            records: records,
            toolEvents: toolEvents
        )
    }

    private func parseRecord(_ line: String, sourcePath: String) throws -> RawParserRecord? {
        guard let data = line.data(using: .utf8) else {
            throw ParserError.unsupportedInput(provider: provider, sourcePath: sourcePath)
        }

        do {
            if let fixtureEntry = try? JSONDecoder.claudeFixtureDecoder.decode(ClaudeFixtureUsageEntry.self, from: data),
               fixtureEntry.type == "usage" {
                return rawRecord(from: fixtureEntry, sourcePath: sourcePath)
            }

            let entry = try JSONDecoder.claudeFixtureDecoder.decode(ClaudeTranscriptEntry.self, from: data)

            guard entry.type == "assistant", let message = entry.message, let usage = message.usage else {
                return nil
            }

            let inputTokens = usage.inputTokens
            let outputTokens = usage.outputTokens
            let totalTokens = usage.totalTokens ?? sumTokens(
                usage.totalInputTokens,
                outputTokens
            )

            return RawParserRecord(
                model: message.model,
                projectPath: entry.cwd,
                projectName: projectName(from: entry.cwd),
                providerSessionId: entry.sessionId ?? entry.sessionID,
                startTime: entry.timestamp,
                endTime: nil,
                durationSeconds: nil,
                inputTokens: inputTokens,
                cacheCreationInputTokens: usage.cacheCreationInputTokens,
                cacheReadInputTokens: usage.cacheReadInputTokens,
                outputTokens: outputTokens,
                totalTokens: totalTokens,
                rawSourcePath: sourcePath
            )
        } catch let error as ParserError {
            throw error
        } catch {
            throw ParserError.unsupportedInput(provider: provider, sourcePath: sourcePath)
        }
    }

    private func parseToolEvents(
        _ line: String,
        sourcePath: String,
        toolEvents: inout [RawToolEvent],
        toolEventIndexesByCallId: inout [String: Int]
    ) throws {
        guard let data = line.data(using: .utf8) else {
            throw ParserError.unsupportedInput(provider: provider, sourcePath: sourcePath)
        }

        do {
            let entry = try JSONDecoder.claudeFixtureDecoder.decode(ClaudeTranscriptEntry.self, from: data)

            if entry.type == "assistant", let toolUses = entry.message?.content?.toolUses {
                for toolUse in toolUses {
                    let event = RawToolEvent(
                        providerSessionId: entry.sessionId ?? entry.sessionID,
                        timestamp: entry.timestamp,
                        toolName: toolUse.name,
                        targetPath: Self.targetPath(from: toolUse),
                        command: Self.command(from: toolUse),
                        workingDirectory: entry.cwd,
                        toolCallId: toolUse.id,
                        rawSourcePath: sourcePath
                    )
                    toolEvents.append(event)

                    if let id = event.toolCallId {
                        toolEventIndexesByCallId[id] = toolEvents.count - 1
                    }
                }
            }

            if let toolResults = entry.message?.content?.toolResults {
                for toolResult in toolResults where toolResult.isError == true {
                    guard let index = toolEventIndexesByCallId[toolResult.toolUseId] else {
                        continue
                    }

                    toolEvents[index].exitCode = toolResult.exitCode ?? 1
                    toolEvents[index].errorSummary = toolResult.errorSummary
                        ?? Self.errorSummary(from: toolResult.content)
                        ?? "Tool failed"
                }
            }
        } catch {
            throw ParserError.unsupportedInput(provider: provider, sourcePath: sourcePath)
        }
    }

    private func rawRecord(from entry: ClaudeFixtureUsageEntry, sourcePath: String) -> RawParserRecord {
        let inputTokens = entry.usage.inputTokens
        let outputTokens = entry.usage.outputTokens
        let totalTokens = entry.usage.totalTokens ?? sumTokens(entry.usage.totalInputTokens, outputTokens)

        return RawParserRecord(
            model: entry.model,
            projectPath: entry.projectPath ?? entry.cwd,
            projectName: entry.projectName,
            providerSessionId: entry.sessionId,
            startTime: entry.timestamp,
            endTime: entry.endTime,
            durationSeconds: entry.durationSeconds,
            inputTokens: inputTokens,
            cacheCreationInputTokens: entry.usage.cacheCreationInputTokens,
            cacheReadInputTokens: entry.usage.cacheReadInputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens,
            rawSourcePath: sourcePath
        )
    }

    private func projectName(from path: String?) -> String? {
        guard let path, !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func sumTokens(_ inputTokens: Int?, _ outputTokens: Int?) -> Int? {
        guard inputTokens != nil || outputTokens != nil else {
            return nil
        }

        return (inputTokens ?? 0) + (outputTokens ?? 0)
    }

    private static func targetPath(from toolUse: ClaudeToolUseBlock) -> String? {
        stringInput("file_path", from: toolUse.input)
            ?? stringInput("path", from: toolUse.input)
    }

    private static func command(from toolUse: ClaudeToolUseBlock) -> String? {
        stringInput("command", from: toolUse.input)
    }

    private static func stringInput(_ key: String, from input: [String: JSONValue]?) -> String? {
        input?[key]?.stringValue
    }

    private static func errorSummary(from content: String?) -> String? {
        guard let content else {
            return nil
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return String(trimmed.prefix(120))
    }
}

private struct ClaudeFixtureUsageEntry: Decodable {
    var type: String
    var timestamp: Date?
    var endTime: Date?
    var durationSeconds: Int?
    var sessionId: String?
    var model: String?
    var cwd: String?
    var projectPath: String?
    var projectName: String?
    var usage: ClaudeUsage

    enum CodingKeys: String, CodingKey {
        case type
        case timestamp
        case endTime = "end_time"
        case durationSeconds = "duration_seconds"
        case sessionId = "session_id"
        case model
        case cwd
        case projectPath = "project_path"
        case projectName = "project_name"
        case usage
    }
}

private struct ClaudeUsage: Decodable {
    var inputTokens: Int?
    var cacheCreationInputTokens: Int?
    var cacheReadInputTokens: Int?
    var outputTokens: Int?
    var totalTokens: Int?

    var totalInputTokens: Int? {
        let values = [
            inputTokens,
            cacheCreationInputTokens,
            cacheReadInputTokens
        ].compactMap { $0 }

        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +)
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

private struct ClaudeTranscriptEntry: Decodable {
    var type: String
    var timestamp: Date?
    var sessionId: String?
    var sessionID: String?
    var cwd: String?
    var message: ClaudeTranscriptMessage?

    enum CodingKeys: String, CodingKey {
        case type
        case timestamp
        case sessionId
        case sessionID = "session_id"
        case cwd
        case message
    }
}

private struct ClaudeTranscriptMessage: Decodable {
    var model: String?
    var usage: ClaudeTranscriptUsage?
    var content: ClaudeMessageContent?
}

private struct ClaudeMessageContent: Decodable {
    var toolUses: [ClaudeToolUseBlock]
    var toolResults: [ClaudeToolResultBlock]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if (try? container.decode(String.self)) != nil {
            toolUses = []
            toolResults = []
        } else {
            let blocks = (try? container.decode([ClaudeContentBlock].self)) ?? []
            toolUses = blocks.compactMap(\.toolUse)
            toolResults = blocks.compactMap(\.toolResult)
        }
    }
}

private struct ClaudeContentBlock: Decodable {
    var toolUse: ClaudeToolUseBlock?
    var toolResult: ClaudeToolResultBlock?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let toolUse = try? container.decode(ClaudeToolUseBlock.self), toolUse.type == "tool_use" {
            self.toolUse = toolUse
            self.toolResult = nil
        } else if let toolResult = try? container.decode(ClaudeToolResultBlock.self), toolResult.type == "tool_result" {
            self.toolUse = nil
            self.toolResult = toolResult
        } else {
            self.toolUse = nil
            self.toolResult = nil
        }
    }
}

private struct ClaudeToolUseBlock: Decodable {
    var type: String
    var id: String?
    var name: String
    var input: [String: JSONValue]?
}

private struct ClaudeToolResultBlock: Decodable {
    var type: String
    var toolUseId: String
    var isError: Bool?
    var content: String?
    var exitCode: Int?
    var errorSummary: String?

    enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case isError = "is_error"
        case content
        case exitCode = "exit_code"
        case errorSummary = "error_summary"
    }
}

private struct ClaudeTranscriptUsage: Decodable {
    var inputTokens: Int?
    var cacheCreationInputTokens: Int?
    var cacheReadInputTokens: Int?
    var outputTokens: Int?
    var totalTokens: Int?

    var totalInputTokens: Int? {
        let values = [
            inputTokens,
            cacheCreationInputTokens,
            cacheReadInputTokens
        ].compactMap { $0 }

        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +)
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

private extension JSONDecoder {
    static var claudeFixtureDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        // `.iso8601` rejects fractional seconds on older Foundation versions,
        // so accept both `2026-07-10T10:00:00Z` and `2026-07-10T10:00:00.000Z`.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized ISO 8601 timestamp: \(value)"
            )
        }
        return decoder
    }
}
