import Algorithms
import Everything
import Foundation

public enum BlueprintError: Error {
//    @available(*, deprecated, message: "Create better errors.")
    case unknown
//    @available(*, deprecated, message: "Create better errors.")
    case generic(String)
    case failedToResolveName(String)
}

extension CharacterSet: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = CharacterSet(charactersIn: value)
    }
}

extension CharacterSet {
    static func + (lhs: CharacterSet, rhs: CharacterSet) -> CharacterSet {
        lhs.union(rhs)
    }
}

extension Character {
    static func random(in set: String) -> Character {
        set.randomElement()!
    }
}

// MARK: -

extension URL: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(string: value)!
    }
}

public struct URLPath: Hashable, Sendable {
    public let rawValue: String

    public init(_ path: String) {
        rawValue = path
    }
}

extension URLPath: Comparable {
    public static func < (lhs: URLPath, rhs: URLPath) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension URLPath: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        rawValue = value
    }
}

extension URLPath: ExpressibleByStringInterpolation {
    public init(stringInterpolation: DefaultStringInterpolation) {
        rawValue = stringInterpolation.description // TODO?????
    }
}

extension URLPath: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

extension Array: Request where Element: Request {
    public func apply(request: inout PartialRequest) throws {
        try forEach { element in
            try element.apply(request: &request)
        }
    }
}

public struct OverrideURLRequest: Request {
    let content: any Request
    let overrideURL: URL?

    public init(content: any Request, overrideURL: URL?) {
        self.content = content
        self.overrideURL = overrideURL
    }

    public var request: some Request {
        content
        overrideURL
    }
}

// MARK: -

public enum Chunk {
    case string(String)
    case data(Data)
}

extension Chunk: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension Chunk: ExpressibleByStringInterpolation {
}

public extension Data {
    init<C>(_ chunks: C) where C: Collection, C.Element == Chunk {
        self = chunks.reduce(into: Data()) { partialResult, chunk in
            switch chunk {
            case .data(let data):
                partialResult += data
            case .string(let string):
                partialResult += string.utf8
            }
        }
    }
}

// MARK: -

public extension PartialRequest {
    var data: Data {
        var chunks: [Chunk] = [
            "\(method.rawValue) \(url?.path ?? "/") HTTP/1.1"
        ]
        + headers.map { header in
            .string("\(header.name): \(header.value)")
        }
        + [""]
        + [.data(body ?? Data())]
        return Data(chunks.interspersed(with: "\r\n"))
    }
}

