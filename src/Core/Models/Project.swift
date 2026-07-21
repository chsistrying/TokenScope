import Foundation

public struct Project: Equatable, Codable, Sendable {
    public var id: String
    public var name: String
    public var path: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case path
    }

    public init(id: String, name: String, path: String?) {
        self.id = id
        self.name = name
        self.path = path
    }
}
