import Foundation

public enum BlueprintError: Error {
    case unknown
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

