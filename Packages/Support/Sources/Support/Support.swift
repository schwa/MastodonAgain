public struct CompositeHash<Element>: Hashable where Element: Hashable {
    let elements: [Element]

    public init(_ elements: [Element]) {
        self.elements = elements
    }
}

extension CompositeHash: Sendable where Element: Sendable {
}

extension CompositeHash: Codable where Element: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        elements = try container.decode([Element].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(elements)
    }
}

extension CompositeHash: Comparable where Element: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        let max = max(lhs.elements.count, rhs.elements.count)
        let lhs = lhs.elements.extended(count: max)
        let rhs = rhs.elements.extended(count: max)
        for (lhs, rhs) in zip(lhs, rhs) {
            switch (lhs, rhs) {
            case (.none, .none):
                fatalError("Should be impossible to be get here.")
            case (.some, .none):
                return false
            case (.none, .some):
                return true
            case (.some(let lhs), .some(let rhs)):
                if lhs < rhs {
                    return true
                }
                else if lhs > rhs {
                    return false
                }
                else {
                    continue
                }
            }
        }
        return false
    }
}

internal extension Collection {
    func extended(count: Int) -> [Element?] {
        let extra = count - self.count
        return map { Optional($0) } + repeatElement(nil, count: extra)
    }
}
