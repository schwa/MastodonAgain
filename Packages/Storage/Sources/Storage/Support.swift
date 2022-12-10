import Foundation
@_implementationOnly import os

internal let moduleLogger: Logger? = Logger()

internal extension iovec {
    // swiftlint:disable:next implicitly_unwrapped_optional
    init(iov_base: UnsafeRawPointer!, iov_len: Int) {
        self = iovec(iov_base: UnsafeMutableRawPointer(mutating: iov_base), iov_len: iov_len)
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
