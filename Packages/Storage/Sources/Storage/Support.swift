import Foundation
import os

internal let moduleLogger: Logger? = Logger()

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

public extension Storage.Registration {
    mutating func registerJSON(type: (some Codable).Type, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        register(type: type) {
            // TODO: Temporarily force try! to cause early issues
            // swiftlint:disable:next force_try
            do {
                return try encoder.encode($0)
            }
            catch {
                moduleLogger?.error("Failed to encode: \(String(describing: $0))")
                throw error
            }
        } decoder: {
            // TODO: Temporarily force try! to cause early issues
            // swiftlint:disable:next force_try
            do {
                return try decoder.decode(type, from: $0)
            }
            catch {
                moduleLogger?.error("Failed to decode: \($0)")
                throw error
            }
        }
    }
}
