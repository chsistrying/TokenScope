import Foundation

public struct NormalizedSession: Equatable, Codable, Sendable {
    public var id: String
    public var provider: Provider
    public var model: String
    public var projectPath: String?
    public var projectName: String
    public var sessionId: String
    public var startTime: Date
    public var endTime: Date?
    public var durationSeconds: Int?
    public var inputTokens: Int?
    public var cacheCreationInputTokens: Int?
    public var cacheReadInputTokens: Int?
    public var outputTokens: Int?
    public var totalTokens: Int?
    public var estimatedCost: Decimal?
    public var rawSourcePath: String

    private enum CodingKeys: String, CodingKey {
        case id
        case provider
        case model
        case projectPath
        case projectName
        case sessionId
        case startTime
        case endTime
        case durationSeconds
        case inputTokens
        case cacheCreationInputTokens
        case cacheReadInputTokens
        case outputTokens
        case totalTokens
        case estimatedCost
        case rawSourcePath
    }

    public init(
        id: String,
        provider: Provider,
        model: String,
        projectPath: String?,
        projectName: String,
        sessionId: String,
        startTime: Date,
        endTime: Date?,
        durationSeconds: Int?,
        inputTokens: Int?,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        outputTokens: Int?,
        totalTokens: Int?,
        estimatedCost: Decimal?,
        rawSourcePath: String
    ) {
        self.id = id
        self.provider = provider
        self.model = model
        self.projectPath = projectPath
        self.projectName = projectName
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.inputTokens = inputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.estimatedCost = estimatedCost
        self.rawSourcePath = rawSourcePath
    }
}
