import Foundation

public struct TypeID: Hashable {

    public let rawValue: String

    public init<T>(_ type: T.Type) {
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

struct WeakBox <Content> where Content: AnyObject {
    weak var content: Content?

    init(_ content: Content) {
        self.content = content
    }
}
