import Foundation

public struct TypeID: Hashable {
    public let rawValue: String

    public init(_ type: (some Any).Type) {
        rawValue = String(describing: type)
    }
}

extension TypeID: Codable {
}

// MARK: -

internal extension iovec {
    // swiftlint:disable:next implicitly_unwrapped_optional
    init(iov_base: UnsafeRawPointer!, iov_len: Int) {
        self = iovec(iov_base: UnsafeMutableRawPointer(mutating: iov_base), iov_len: iov_len)
    }
}

public struct WeakBox<Content> where Content: AnyObject {
    public weak var content: Content?

    public init(_ content: Content) {
        self.content = content
    }
}

public extension Storage {
    func registerJSON(type: (some Codable).Type, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        register(type: type) {
            try encoder.encode($0)
        } decoder: {
            try decoder.decode(type, from: $0)
        }
    }
}
