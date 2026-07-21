import Foundation

public struct CodexParser: ProviderParsing {
    public let provider: Provider = .codex

    public init() {}

    public func parse(_ input: ParserInput) throws -> RawParserResult {
        guard let contents = input.contents, contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw ParserError.noData(provider: provider, sourcePath: input.sourcePath)
        }

        guard let data = contents.data(using: .utf8) else {
            throw ParserError.unsupportedInput(provider: provider, sourcePath: input.sourcePath)
        }

        do {
            if let fixture = try? JSONDecoder().decode(CodexFixture.self, from: data) {
                let records = try fixture.records.map { fixtureRecord in
                    try rawRecord(from: fixtureRecord, sourcePath: input.sourcePath)
                }

                guard records.isEmpty == false else {
                    throw ParserError.noData(provider: provider, sourcePath: input.sourcePath)
                }

                return RawParserResult(provider: provider, sourcePath: input.sourcePath, records: records)
            }

            let rollout = try parseRollout(contents, sourcePath: input.sourcePath)

            guard !rollout.records.isEmpty || !rollout.toolEvents.isEmpty else {
                throw ParserError.noData(provider: provider, sourcePath: input.sourcePath)
            }

            return RawParserResult(
                provider: provider,
                sourcePath: input.sourcePath,
                records: rollout.records,
                toolEvents: rollout.toolEvents
            )
        } catch let error as ParserError {
            throw error
        } catch {
            throw ParserError.unsupportedInput(provider: provider, sourcePath: input.sourcePath)
        }
    }

    private func parseRollout(_ contents: String, sourcePath: String) throws -> (records: [RawParserRecord], toolEvents: [RawToolEvent]) {
        let lines = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var sessionId: String?
        var model: String?
        var projectPath: String?
        var latestTokenEvent: CodexRolloutTokenEvent?
        var toolEvents: [RawToolEvent] = []
        var sawUnsupportedLine = false

        for line in lines {
            guard let data = line.data(using: .utf8) else {
                continue
            }

            let event: CodexRolloutEvent
            do {
                event = try JSONDecoder().decode(CodexRolloutEvent.self, from: data)
            } catch {
                sawUnsupportedLine = true
                continue
            }

            switch event.type {
            case "session_meta":
                sessionId = event.payload.sessionId ?? event.payload.id ?? sessionId
                projectPath = event.payload.cwd ?? projectPath
            case "turn_context":
                model = event.payload.model ?? model
                projectPath = event.payload.cwd ?? projectPath
            case "event_msg" where event.payload.type == "token_count":
                if let usage = event.payload.info?.lastTokenUsage ?? event.payload.info?.totalTokenUsage {
                    latestTokenEvent = CodexRolloutTokenEvent(
                        timestamp: try parseDate(event.timestamp, sourcePath: sourcePath),
                        usage: usage
                    )
                }
            case "event_msg":
                if let toolEvent = try rawToolEvent(
                    from: event,
                    sessionId: sessionId,
                    workingDirectory: event.payload.cwd ?? projectPath,
                    sourcePath: sourcePath
                ) {
                    toolEvents.append(toolEvent)
                }
            default:
                continue
            }
        }

        guard let latestTokenEvent else {
            if sawUnsupportedLine {
                throw ParserError.unsupportedInput(provider: provider, sourcePath: sourcePath)
            }

            return ([], toolEvents)
        }

        return ([
            RawParserRecord(
                model: model,
                projectPath: projectPath,
                projectName: projectName(from: projectPath),
                providerSessionId: sessionId ?? sessionIdFromRolloutPath(sourcePath),
                startTime: latestTokenEvent.timestamp,
                endTime: nil,
                durationSeconds: nil,
                inputTokens: latestTokenEvent.usage.inputTokens,
                cacheReadInputTokens: latestTokenEvent.usage.cachedInputTokens,
                outputTokens: latestTokenEvent.usage.outputTokens,
                totalTokens: latestTokenEvent.usage.totalTokens,
                rawSourcePath: sourcePath
            )
        ], toolEvents)
    }

    private func rawRecord(from fixtureRecord: CodexFixture.Record, sourcePath: String) throws -> RawParserRecord {
        let inputTokens = fixtureRecord.usage?.inputTokens
        let outputTokens = fixtureRecord.usage?.outputTokens

        return RawParserRecord(
            model: fixtureRecord.model,
            projectPath: fixtureRecord.project?.path,
            projectName: fixtureRecord.project?.name,
            providerSessionId: fixtureRecord.sessionId,
            startTime: try parseDate(fixtureRecord.startedAt, sourcePath: sourcePath),
            endTime: try parseDate(fixtureRecord.endedAt, sourcePath: sourcePath),
            durationSeconds: fixtureRecord.durationSeconds,
            inputTokens: inputTokens,
            cacheReadInputTokens: fixtureRecord.usage?.cachedInputTokens,
            outputTokens: outputTokens,
            totalTokens: fixtureRecord.usage?.totalTokens ?? sumTokens(inputTokens, outputTokens),
            rawSourcePath: sourcePath
        )
    }

    private func parseDate(_ value: String?, sourcePath: String) throws -> Date? {
        guard let value else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else {
            throw ParserError.unsupportedInput(provider: provider, sourcePath: sourcePath)
        }

        return date
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

    private func sessionIdFromRolloutPath(_ path: String) -> String? {
        let filename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard filename.hasPrefix("rollout-") else {
            return nil
        }

        return filename
    }

    private func rawToolEvent(
        from event: CodexRolloutEvent,
        sessionId: String?,
        workingDirectory: String?,
        sourcePath: String
    ) throws -> RawToolEvent? {
        let toolName = event.payload.name ?? event.payload.toolName ?? event.payload.type
        guard let toolName, isToolEvent(type: event.payload.type, toolName: toolName) else {
            return nil
        }

        return RawToolEvent(
            providerSessionId: sessionId ?? event.payload.sessionId,
            timestamp: try parseDate(event.timestamp, sourcePath: sourcePath),
            toolName: toolName,
            targetPath: event.payload.targetPath,
            command: event.payload.command,
            workingDirectory: workingDirectory,
            toolCallId: event.payload.toolCallId ?? event.payload.id,
            exitCode: event.payload.exitCode,
            errorSummary: event.payload.errorSummary,
            rawSourcePath: sourcePath
        )
    }

    private func isToolEvent(type: String?, toolName: String) -> Bool {
        let normalizedType = type?.lowercased()
        let normalizedToolName = toolName.lowercased()
        return normalizedType == "tool_call"
            || normalizedType == "exec_command"
            || normalizedToolName == "read"
            || normalizedToolName == "bash"
            || normalizedToolName == "exec_command"
    }
}

private struct CodexFixture: Decodable {
    var records: [Record]

    struct Record: Decodable {
        var sessionId: String?
        var model: String?
        var startedAt: String?
        var endedAt: String?
        var durationSeconds: Int?
        var usage: Usage?
        var project: Project?

        private enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case model
            case startedAt = "started_at"
            case endedAt = "ended_at"
            case durationSeconds = "duration_seconds"
            case usage
            case project
        }
    }

    struct Usage: Decodable {
        var inputTokens: Int?
        var cachedInputTokens: Int?
        var outputTokens: Int?
        var totalTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case cachedInputTokens = "cached_input_tokens"
            case outputTokens = "output_tokens"
            case totalTokens = "total_tokens"
        }
    }

    struct Project: Decodable {
        var path: String?
        var name: String?
    }
}

private struct CodexRolloutEvent: Decodable {
    var timestamp: String?
    var type: String
    var payload: Payload

    struct Payload: Decodable {
        var type: String?
        var id: String?
        var sessionId: String?
        var cwd: String?
        var model: String?
        var info: TokenInfo?
        var name: String?
        var toolName: String?
        var targetPath: String?
        var command: String?
        var toolCallId: String?
        var exitCode: Int?
        var errorSummary: String?

        private enum CodingKeys: String, CodingKey {
            case type
            case id
            case sessionId = "session_id"
            case cwd
            case model
            case info
            case name
            case toolName = "tool_name"
            case targetPath = "target_path"
            case command
            case toolCallId = "tool_call_id"
            case callId = "call_id"
            case exitCode = "exit_code"
            case status
            case stderr
            case error
            case errorSummary = "error_summary"
            case arguments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decodeIfPresent(String.self, forKey: .type)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
            cwd = try container.decodeIfPresent(String.self, forKey: .cwd)
            model = try container.decodeIfPresent(String.self, forKey: .model)
            info = try container.decodeIfPresent(TokenInfo.self, forKey: .info)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
            targetPath = try container.decodeIfPresent(String.self, forKey: .targetPath)
            command = try container.decodeIfPresent(String.self, forKey: .command)
            toolCallId = try container.decodeIfPresent(String.self, forKey: .toolCallId)
                ?? container.decodeIfPresent(String.self, forKey: .callId)
            exitCode = try container.decodeIfPresent(Int.self, forKey: .exitCode)
            errorSummary = try container.decodeIfPresent(String.self, forKey: .errorSummary)
                ?? container.decodeIfPresent(String.self, forKey: .stderr)
                ?? container.decodeIfPresent(String.self, forKey: .error)

            if exitCode == nil,
               let status = try container.decodeIfPresent(String.self, forKey: .status)?.lowercased(),
               status == "failed" || status == "error" {
                exitCode = 1
            }

            if let arguments = try container.decodeIfPresent([String: JSONValue].self, forKey: .arguments) {
                targetPath = targetPath
                    ?? arguments["file_path"]?.stringValue
                    ?? arguments["path"]?.stringValue
                command = command ?? arguments["command"]?.stringValue
                toolCallId = toolCallId
                    ?? arguments["tool_call_id"]?.stringValue
                    ?? arguments["call_id"]?.stringValue
            }
        }
    }

    struct TokenInfo: Decodable {
        var totalTokenUsage: TokenUsage?
        var lastTokenUsage: TokenUsage?

        private enum CodingKeys: String, CodingKey {
            case totalTokenUsage = "total_token_usage"
            case lastTokenUsage = "last_token_usage"
        }
    }

    struct TokenUsage: Decodable {
        var inputTokens: Int?
        var cachedInputTokens: Int?
        var outputTokens: Int?
        var totalTokens: Int?

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case cachedInputTokens = "cached_input_tokens"
            case outputTokens = "output_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

private struct CodexRolloutTokenEvent {
    var timestamp: Date?
    var usage: CodexRolloutEvent.TokenUsage
}
