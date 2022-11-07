import Foundation

public struct Host: Codable, Sendable, Hashable {
    public let url: URL

    public init(_ host: String) {
        url = URL(string: "https://host/")!
    }
}

public enum Authorization: Codable, Hashable, Sendable {
    case unauthorized
    case registered(RegisteredApplication)
    case authorized(RegisteredApplication, Token)
}

public extension Authorization {
    var token: Token? {
        guard case .authorized(_, let token) = self else {
            return nil
        }
        return token
    }
}
