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
        return set.randomElement()!
    }
}

extension String {
    static func random(count: Int, of set: String) -> String {
        String((0 ..< count).map({ _ in Character.random(in: set) }))
    }
}

extension URL: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(string: value)!
    }
}

public struct URLPath: Hashable {
    public let rawValue: String

    public init(_ path: String) {
        self.rawValue = path
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
