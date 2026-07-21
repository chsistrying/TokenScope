import Foundation

public struct UsageEvent: Equatable, Codable, Sendable {
    public var id: String
    public var sessionId: String
    public var timestamp: Date
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var totalTokens: Int?
    public var estimatedCost: Decimal?
    public var rawSourcePath: String

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionId
        case timestamp
        case inputTokens
        case outputTokens
        case totalTokens
        case estimatedCost
        case rawSourcePath
    }

    public init(
        id: String,
        sessionId: String,
        timestamp: Date,
        inputTokens: Int?,
        outputTokens: Int?,
        totalTokens: Int?,
        estimatedCost: Decimal?,
        rawSourcePath: String
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.estimatedCost = estimatedCost
        self.rawSourcePath = rawSourcePath
    }
}
