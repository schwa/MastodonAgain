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

    public enum BroadcasterKey: Hashable, Sendable {
        case timeline(Timeline)
        case relationships
        case status(Status.ID)
    }

    internal var broadcasters: [BroadcasterKey: AnyAsyncChannelBroadcaster] = [:]

    public init(host: String, authorization: Authorization) throws {
        self.host = host
        self.authorization = authorization

        let version = 2 // TODO: Move into constants
        let filename = "\(host.replacing(".", with: "-")).v\(version)-storage.data"
        let path = try FSPath.specialDirectory(.cachesDirectory) / filename
        storage = try Storage(path: path.path) { registration in
            registration.registerJSON(type: Dated<Status>.self)
            registration.registerJSON(type: Timeline.Content.self)
            registration.registerJSON(type: Status.self)
            registration.registerJSON(type: [Account.ID: Relationship].self)
        }
    }

    public func update(_ value: Status) async throws {
        // TODO: Insert by date
        try await storage.set(key: value.id.rawValue, value: Dated<Status>(value))
    }

    public func update(_ other: some Collection<Status>) async throws {
        let now = Date.now
        for value in other {
            try await storage.set(key: [value.id.rawValue], value: Dated(value, date: now))
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
        let result = try await session.perform(request: request, resultGenerator: resultGenerator)
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

    func perform<R>(_ requestResponse: @Sendable (URL, Token) -> R) async throws -> R.Result where R: Request & Response {
        let requestResponse = requestResponse(baseURL, authorization.token!)
        return try await perform(requestResponse: requestResponse)
    }
}

// MARK: -

public final class AsyncChannelBroadcaster<Element> where Element: Sendable {
    @MainActor
    public var channels: [WeakBox<AsyncChannel<Element>>] = []

    public init() {
    }

    public func broadcast(_ element: Element) async {
        for channel in await channels {
            await channel.content?.send(element)
        }
    }

    public func makeChannel() async -> AsyncChannel<Element> {
        let channel = AsyncChannel<Element>()
        await MainActor.run {
            channels.append(WeakBox(channel))
        }
        return channel
    }
}

public final class AnyAsyncChannelBroadcaster {
    public let base: Any

    public init(_ base: AsyncChannelBroadcaster<some Any>) {
        self.base = base
    }
}

public extension Service {
    func fetchStatus(id: Status.ID) async throws -> Status? {
        let broadcaster = broadcaster(for: .status(id), element: Status.self)
        let status = try await storage.get(key: id, type: Status.self)
        if let status {
            return status
        }
        else {
            Task {
                await tryElseLog {
                    let status = try await perform { baseURL, token in
                        MastodonAPI.Statuses.View(baseURL: baseURL, token: token, id: id)
                    }
                    try await storage.set(key: id, value: status)
                    await broadcaster.broadcast(status)
                }
            }
            return nil
        }
    }
}

public func tryElseLog<R>(_ type: OSLogType = .error, _ message: @autoclosure () -> String = String(), _ block: () async throws -> R) async -> R? {
    do {
        return try await block()
    }
    catch {
        let message = message()
        if message.isEmpty {
            os_log(type, "%s", String(describing: error))
        }
        else {
            os_log(type, "%s: %s", message, String(describing: error))
        }
        return nil
    }
}
