public struct Comment: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let email: String
    public let body: String

    public init(id: Int, name: String, email: String, body: String) {
        self.id = id
        self.name = name
        self.email = email
        self.body = body
    }
}
