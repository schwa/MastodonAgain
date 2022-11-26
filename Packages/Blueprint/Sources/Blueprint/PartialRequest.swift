import Foundation

public struct PartialRequest: Hashable, Sendable {
    public var url: URL?
    public var method: Method
    public var headers: [Header]
    public var body: Data?

    public init(url: URL? = nil, method: Method = .get, headers: [Header] = [], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public enum Method: String, Sendable {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

public struct Header: Hashable, Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

extension Header: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let regex = #/^(.+)=(.+)$/#
        guard let match = value.firstMatch(of: regex) else {
            fatalError("Header doesn't match pattern")
        }
        let (_, name, value) = match.output
        self = .init(name: String(name), value: String(value))
    }
}

public extension URLRequest {
    init(_ request: PartialRequest) throws {
        guard let url = request.url else {
            fatalError("Could not find a url")
        }
        self.init(url: url)
        httpMethod = request.method.rawValue
        request.headers.forEach { header in
            setValue(header.value, forHTTPHeaderField: header.name)
        }
        httpBody = request.body
    }
}
