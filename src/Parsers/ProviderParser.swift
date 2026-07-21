import Foundation

public struct ParserInput: Equatable, Sendable {
    public var sourcePath: String
    public var contents: String?

    public init(sourcePath: String, contents: String? = nil) {
        self.sourcePath = sourcePath
        self.contents = contents
    }
}

public struct RawParserRecord: Equatable, Sendable {
    public var model: String?
    public var projectPath: String?
    public var projectName: String?
    public var providerSessionId: String?
    public var startTime: Date?
    public var endTime: Date?
    public var durationSeconds: Int?
    public var inputTokens: Int?
    public var cacheCreationInputTokens: Int?
    public var cacheReadInputTokens: Int?
    public var outputTokens: Int?
    public var totalTokens: Int?
    public var rawSourcePath: String

    public init(
        model: String? = nil,
        projectPath: String? = nil,
        projectName: String? = nil,
        providerSessionId: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        durationSeconds: Int? = nil,
        inputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil,
        rawSourcePath: String
    ) {
        self.model = model
        self.projectPath = projectPath
        self.projectName = projectName
        self.providerSessionId = providerSessionId
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.inputTokens = inputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.rawSourcePath = rawSourcePath
    }
}

public struct RawToolEvent: Equatable, Sendable {
    public var providerSessionId: String?
    public var timestamp: Date?
    public var toolName: String
    public var targetPath: String?
    public var command: String?
    public var workingDirectory: String?
    public var toolCallId: String?
    public var exitCode: Int?
    public var errorSummary: String?
    public var rawSourcePath: String

    public init(
        providerSessionId: String? = nil,
        timestamp: Date? = nil,
        toolName: String,
        targetPath: String? = nil,
        command: String? = nil,
        workingDirectory: String? = nil,
        toolCallId: String? = nil,
        exitCode: Int? = nil,
        errorSummary: String? = nil,
        rawSourcePath: String
    ) {
        self.providerSessionId = providerSessionId
        self.timestamp = timestamp
        self.toolName = toolName
        self.targetPath = targetPath
        self.command = command
        self.workingDirectory = workingDirectory
        self.toolCallId = toolCallId
        self.exitCode = exitCode
        self.errorSummary = errorSummary
        self.rawSourcePath = rawSourcePath
    }
}

public struct RawParserResult: Equatable, Sendable {
    public var provider: Provider
    public var sourcePath: String
    public var records: [RawParserRecord]
    public var toolEvents: [RawToolEvent]

    public init(
        provider: Provider,
        sourcePath: String,
        records: [RawParserRecord] = [],
        toolEvents: [RawToolEvent] = []
    ) {
        self.provider = provider
        self.sourcePath = sourcePath
        self.records = records
        self.toolEvents = toolEvents
    }
}

public typealias ParserResult = RawParserResult

public enum ParserError: Error, Equatable, Sendable {
    case noData(provider: Provider, sourcePath: String)
    case unsupportedInput(provider: Provider, sourcePath: String)
}

public protocol ProviderParsing {
    var provider: Provider { get }

    func parse(_ input: ParserInput) throws -> RawParserResult
}
