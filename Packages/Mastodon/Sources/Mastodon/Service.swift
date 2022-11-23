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

    // TODO: There's a whole lot of any going on.

    public enum BroadcasterKey: Hashable {
        case timeline(Timeline)
        case relationships
    }

    internal var broadcasters: [BroadcasterKey: AnyAsyncChannelBroadcaster] = [:]

    public init(host: String, authorization: Authorization) {
        self.host = host
        self.authorization = authorization

        do {
            let path = (try FSPath.specialDirectory(.cachesDirectory) / host.replacing(".", with: "-")).withPathExtension("v1-storage.data")
            storage = Storage()
            storage.registerJSON(type: Dated<Status>.self)
            storage.registerJSON(type: Timeline.Content.self)
            storage.registerJSON(type: [Account.ID: Relationship].self)
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

// MARK: -

public extension Service {
    // TODO: Decide what to deprecate here.

    func perform<R2>(request: some Request, response: R2) async throws -> R2.Result where R2: Response {
        guard let resultGenerator = response.response as? any ResultGenerator else {
            fatalError("Could not get a result generator from a response.")
        }
        let result = try await session.perform(request: request, response: resultGenerator)
        guard let result = result as? R2.Result else {
            fatalError("Could not get a result of the correct type.")
        }
        return result
    }

    func perform<R>(requestResponse: R) async throws -> R.Result where R: Request & Response {
        try await perform(request: requestResponse, response: requestResponse)
    }

    func perform<R>(_ requestResponse: R) async throws -> R.Result where R: Request & Response {
        try await perform(request: requestResponse, response: requestResponse)
    }

    func perform<R>(_ requestResponse: (URL, Token) -> R) async throws -> R.Result where R: Request & Response {
        let requestResponse = requestResponse(baseURL, authorization.token!)
        return try await perform(requestResponse: requestResponse)
    }
}

// MARK: -

public extension Service {
    @available(*, deprecated, message: "Use MastodonAPI directly")
    func status(for id: Status.ID) async -> Status? {
        storage[id.rawValue, Dated<Status>.self]?.content
    }
}

public class AsyncChannelBroadcaster<Element> where Element: Sendable {
    public var channels: [WeakBox<AsyncChannel<Element>>] = []

    public init() {
    }

    public func broadcast(_ element: Element) async {
        for channel in channels {
            await channel.content?.send(element)
        }
    }

    public func makeChannel() -> AsyncChannel<Element> {
        let channel = AsyncChannel<Element>()
        channels.append(WeakBox(channel))
        return channel
    }
}

public class AnyAsyncChannelBroadcaster {
    public let base: Any

    public init(_ base: AsyncChannelBroadcaster<some Any>) {
        self.base = base
    }

//    public func broadcast <Element>(_ element: Element) async where Element: Sendable {
//        // swiftlint:disable:next force_cast
//        let base = base as! AsyncChannelBroadcaster<Element>
//        await base.broadcast(element)
//    }
//
//    public func makeChannel <Element>() -> AsyncChannel<Element> where Element: Sendable {
//        // swiftlint:disable:next force_cast
//        let base = base as! AsyncChannelBroadcaster<Element>
//        return base.makeChannel()
//    }
}
