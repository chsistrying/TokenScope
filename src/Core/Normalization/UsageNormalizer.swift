import Foundation

public protocol UsageNormalizing {
    func normalize(_ result: ParserResult) throws -> [NormalizedSession]
}

public protocol UsageBatchNormalizing: UsageNormalizing {
    func normalizeBatch(_ result: ParserResult) throws -> NormalizedUsageBatch
}

public struct RawUsageNormalizer: UsageNormalizing {
    private static let fallbackStartTime = Date(timeIntervalSince1970: 0)
    private let pricingCatalog: PricingCatalog

    public init(pricingCatalog: PricingCatalog = PricingCatalog()) {
        self.pricingCatalog = pricingCatalog
    }

    public func normalize(_ result: ParserResult) throws -> [NormalizedSession] {
        try normalizedSessions(from: result)
    }

    public func normalizeBatch(_ result: ParserResult) throws -> NormalizedUsageBatch {
        NormalizedUsageBatch(
            sessions: try normalizedSessions(from: result),
            toolEvents: normalizedToolEvents(from: result)
        )
    }

    private func normalizedSessions(from result: ParserResult) throws -> [NormalizedSession] {
        result.records.enumerated().map { index, record in
            let startTime = record.startTime ?? Self.fallbackStartTime
            let sessionId = record.providerSessionId ?? stableSessionId(
                provider: result.provider,
                rawSourcePath: record.rawSourcePath,
                index: index
            )

            return NormalizedSession(
                id: stableSessionRecordId(
                    provider: result.provider,
                    providerSessionId: record.providerSessionId,
                    rawSourcePath: record.rawSourcePath,
                    startTime: record.startTime,
                    index: index
                ),
                provider: result.provider,
                model: record.model ?? "unknown",
                projectPath: record.projectPath,
                projectName: projectName(from: record),
                sessionId: sessionId,
                startTime: startTime,
                endTime: record.endTime,
                durationSeconds: record.durationSeconds,
                inputTokens: record.inputTokens,
                cacheCreationInputTokens: record.cacheCreationInputTokens,
                cacheReadInputTokens: record.cacheReadInputTokens,
                outputTokens: record.outputTokens,
                totalTokens: totalTokens(from: record),
                estimatedCost: pricingCatalog.estimatedCost(
                    provider: result.provider,
                    model: record.model ?? "unknown",
                    inputTokens: record.inputTokens,
                    cacheCreationInputTokens: record.cacheCreationInputTokens,
                    cacheReadInputTokens: record.cacheReadInputTokens,
                    outputTokens: record.outputTokens
                ),
                rawSourcePath: record.rawSourcePath
            )
        }
    }

    private func normalizedToolEvents(from result: ParserResult) -> [ToolEvent] {
        result.toolEvents.enumerated().map { index, event in
            let timestamp = event.timestamp ?? Self.fallbackStartTime
            let sessionId = event.providerSessionId ?? stableSessionId(
                provider: result.provider,
                rawSourcePath: event.rawSourcePath,
                index: index
            )

            return ToolEvent(
                id: stableToolEventId(
                    provider: result.provider,
                    providerSessionId: event.providerSessionId,
                    rawSourcePath: event.rawSourcePath,
                    timestamp: event.timestamp,
                    toolName: event.toolName,
                    targetPath: event.targetPath,
                    command: event.command,
                    workingDirectory: event.workingDirectory,
                    toolCallId: event.toolCallId,
                    exitCode: event.exitCode,
                    errorSummary: event.errorSummary,
                    index: index
                ),
                provider: result.provider,
                sessionId: sessionId,
                timestamp: timestamp,
                toolName: event.toolName,
                targetPath: event.targetPath,
                command: event.command,
                workingDirectory: event.workingDirectory,
                toolCallId: event.toolCallId,
                exitCode: event.exitCode,
                errorSummary: event.errorSummary,
                rawSourcePath: event.rawSourcePath
            )
        }
    }

    private func projectName(from record: RawParserRecord) -> String {
        if let projectName = record.projectName, !projectName.isEmpty {
            return projectName
        }

        if let projectPath = record.projectPath {
            let lastPathComponent = URL(fileURLWithPath: projectPath).lastPathComponent
            if !lastPathComponent.isEmpty {
                return lastPathComponent
            }
        }

        return "unknown"
    }

    private func totalTokens(from record: RawParserRecord) -> Int? {
        if let totalTokens = record.totalTokens {
            return totalTokens
        }

        guard let inputTokens = record.inputTokens, let outputTokens = record.outputTokens else {
            return nil
        }

        return inputTokens + outputTokens
    }

    private func stableSessionRecordId(
        provider: Provider,
        providerSessionId: String?,
        rawSourcePath: String,
        startTime: Date?,
        index: Int
    ) -> String {
        stableID(
            prefix: "normalized-session",
            components: [
                provider.rawValue,
                providerSessionId ?? "",
                rawSourcePath,
                startTime.map(Self.stableDateString) ?? "",
                String(index)
            ]
        )
    }

    private func stableSessionId(
        provider: Provider,
        rawSourcePath: String,
        index: Int
    ) -> String {
        stableID(
            prefix: "generated-session",
            components: [
                provider.rawValue,
                rawSourcePath,
                String(index)
            ]
        )
    }

    private func stableToolEventId(
        provider: Provider,
        providerSessionId: String?,
        rawSourcePath: String,
        timestamp: Date?,
        toolName: String,
        targetPath: String?,
        command: String?,
        workingDirectory: String?,
        toolCallId: String?,
        exitCode: Int?,
        errorSummary: String?,
        index: Int
    ) -> String {
        stableID(
            prefix: "tool-event",
            components: [
                provider.rawValue,
                providerSessionId ?? "",
                rawSourcePath,
                timestamp.map(Self.stableDateString) ?? "",
                toolName,
                targetPath ?? "",
                command ?? "",
                workingDirectory ?? "",
                toolCallId ?? "",
                exitCode.map(String.init) ?? "",
                errorSummary ?? "",
                String(index)
            ]
        )
    }

    private func stableID(prefix: String, components: [String]) -> String {
        "\(prefix)-\(Self.fnv1a64Hex(components.joined(separator: "\u{1F}")))"
    }

    private static func stableDateString(_ date: Date) -> String {
        String(format: "%.6f", date.timeIntervalSince1970)
    }

    private static func fnv1a64Hex(_ string: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3

        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }

        return String(format: "%016llx", hash)
    }
}

extension RawUsageNormalizer: UsageBatchNormalizing {}
