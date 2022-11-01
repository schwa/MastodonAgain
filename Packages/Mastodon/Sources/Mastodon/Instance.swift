public struct Instance: Identifiable, Codable, Hashable, Sendable {
    public var id: String {
        return host
    }

    public var host: String
    public var authorization: Authorization

    public init(_ host: String) {
        self.host = host
        self.authorization = .unauthorized
    }
}

public enum Authorization: Codable, Hashable, Sendable {
    case unauthorized
    case registered(RegisteredApplication)
    case authorized(RegisteredApplication, Token)
}

public extension Instance {
    var token: Token? {
        if case let .authorized(_, token) = authorization {
            return token
        }
        else {
            return nil
        }
    }
}
