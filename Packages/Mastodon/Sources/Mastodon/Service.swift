import AsyncAlgorithms
import Blueprint
import Everything
import Foundation
import os
import RegexBuilder
import Storage
import SwiftUI
import UniformTypeIdentifiers

public actor Service {
    public let host: String
    public let authorization: Authorization
    public let logger: Logger? = Logger()

    public var baseURL: URL {
        URL(string: "https://\(host)")!
    }

    internal let session = URLSession.shared
    internal let decoder = JSONDecoder.mastodonDecoder

    internal let storage: Storage

    public init(host: String, authorization: Authorization) {
        self.host = host
        self.authorization = authorization

        do {
            let path = (try FSPath.specialDirectory(.cachesDirectory) / host.replacing(".", with: "-")).withPathExtension("v1-storage.data")
            storage = Storage()
            storage.registerJSON(type: Dated<Status>.self)
            try storage.open(path: path.path)
            try storage.compact()
        }
        catch {
            fatal(error: error)
        }
    }

    public func update(_ value: Status) {
        // TODO: Insert by date
        storage[value.id.rawValue] = Dated<Status>(value)
    }

    public func update(_ other: some Collection<Status>) {
        let now = Date.now
        for value in other {
            storage[value.id.rawValue] = Dated(value, date: now)
        }
    }
}

public extension Service {
    func perform<R2>(request: some Request, response: R2) async throws -> R2.Result where R2: Response {
        try await session.perform(request: request, response: response)
    }

    func perform<Result>(type: Result.Type, _ requestResponse: (URL, Token) -> some Request & Response) async throws -> Result where Result: Decodable {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        let requestResponse = requestResponse(baseURL, token)
        let result = try await session.perform(requestResponse)
        guard let result = result as? Result else {
            throw MastodonError.generic("Could not cast result to \(type).")
        }
        return result
    }
}

// MARK: -

public extension JSONDecoder {
    static var mastodonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: string) {
                return date
            }
            formatter.formatOptions.remove(.withFullTime)
            if let date = formatter.date(from: string) {
                return date
            }
            fatalError("Failed to decode date \(string)")
        })
        return decoder
    }
}
