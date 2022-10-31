public struct Instance: Identifiable, Codable, Hashable {
    public var id: String {
        return host
    }

    public let host: String

    public init(_ host: String) {
        self.host = host
    }
}
