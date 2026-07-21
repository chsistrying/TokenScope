import Foundation

public struct ToolEvent: Equatable, Codable, Sendable {
    public var id: String
    public var provider: Provider
    public var sessionId: String
    public var timestamp: Date
    public var toolName: String
    public var targetPath: String?
    public var command: String?
    public var workingDirectory: String?
    public var toolCallId: String?
    public var exitCode: Int?
    public var errorSummary: String?
    public var rawSourcePath: String

    public init(
        id: String,
        provider: Provider,
        sessionId: String,
        timestamp: Date,
        toolName: String,
        targetPath: String? = nil,
        command: String? = nil,
        workingDirectory: String? = nil,
        toolCallId: String? = nil,
        exitCode: Int? = nil,
        errorSummary: String? = nil,
        rawSourcePath: String
    ) {
        self.id = id
        self.provider = provider
        self.sessionId = sessionId
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
