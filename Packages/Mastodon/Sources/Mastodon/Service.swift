import AsyncAlgorithms
import Blueprint
import Everything
import Foundation
import os
import RegexBuilder
import SwiftUI
import UniformTypeIdentifiers

private let logger: Logger? = Logger()

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

public struct SignIn: Codable, Identifiable {
    public var id: String {
        name
    }

    public var name: String {
        "@\(account.acct)@\(host)"
    }

    public var host: String
    public var authorization: Authorization
    public var account: Account
    public var avatar: Resource<Image>

    public init(host: String, authorization: Authorization, account: Account, avatar: Resource<Image>) {
        self.host = host
        self.authorization = authorization
        self.account = account
        self.avatar = avatar
    }
}

public actor Service {
    public let host: String
    public let authorization: Authorization

    public var baseURL: URL {
        URL(string: "https://\(host)")!
    }

    internal let session = URLSession.shared
    internal let decoder = JSONDecoder.mastodonDecoder

    internal var datedStatuses: [Status.ID: Dated<Status>] = [:]
    internal var datedAccounts: [Account.ID: Dated<Account>] = [:]

    public init(host: String, authorization: Authorization) {
        self.host = host
        self.authorization = authorization
    }

    public func update(_ value: Status) {
        // TODO: Insert by date
        datedStatuses[value.id] = .init(value)
    }

    public func update(_ other: some Collection<Status>) {
        // TODO: Insert by date
        let now = Date.now
        let other = other.map { Dated($0, date: now) }.map { ($0.content.id, $0) }
        datedStatuses.merge(other) { _, rhs in
            rhs
        }
    }

    public func update(_ value: Account) {
        // TODO: Insert by date
        datedAccounts[value.id] = .init(value)
    }
}

public extension Service {
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

public extension Service {
    @available(*, deprecated, message: "Use MastodonAPI directly")
    func status(for id: Status.ID) async -> Status? {
        datedStatuses[id]?.content
    }

    // TODO: All this needs cleanup. Use URLPath to return a (pre-configured) URLRequest
    @available(*, deprecated, message: "Use MastodonAPI directly")
    func fetchStatus(for id: Status.ID) async throws -> Status {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        // swiftlint:disable:next force_cast
        let status = try await session.perform(MastodonAPI.Statuses.View(baseURL: baseURL, token: token, id: id)) as! Status
        update(status)
        return status
    }

    @available(*, deprecated, message: "Use MastodonAPI directly")
    func account(for id: Account.ID) async -> Account? {
        datedAccounts[id]?.content
    }

    // TODO: All this needs cleanup. Use URLPath to return a (pre-configured) URLRequest
    @available(*, deprecated, message: "Use MastodonAPI directly")
    func fetchAccount(for id: Account.ID) async throws -> Account {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        // swiftlint:disable:next force_cast
        let account = try await session.perform(MastodonAPI.Accounts.Retrieve(baseURL: baseURL, token: token, id: id)) as! Account
        update(account)
        return account
    }

    @available(*, deprecated, message: "Use MastodonAPI directly")
    func favorite(status id: Status.ID, set: Bool = true) async throws -> Status {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }

        let status: Status
        if set {
            // swiftlint:disable:next force_cast
            status = try await session.perform(MastodonAPI.Statuses.Favourite(baseURL: baseURL, token: token, id: id)) as! Status
        }
        else {
            // swiftlint:disable:next force_cast
            status = try await session.perform(MastodonAPI.Statuses.Unfavourite(baseURL: baseURL, token: token, id: id)) as! Status
        }
        update(status)
        return status
    }

    @available(*, deprecated, message: "Use MastodonAPI directly")
    func reblog(status id: Status.ID, set: Bool = true) async throws -> Status {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        let status: Status
        if set {
            // swiftlint:disable:next force_cast
            status = try await session.perform(MastodonAPI.Statuses.Reblog(baseURL: baseURL, token: token, id: id)) as! Status
        }
        else {
            // swiftlint:disable:next force_cast
            status = try await session.perform(MastodonAPI.Statuses.Unreblog(baseURL: baseURL, token: token, id: id)) as! Status
        }
        update(status)
        return status
    }

    @available(*, deprecated, message: "Use MastodonAPI directly")
    func bookmark(status id: Status.ID, set: Bool = true) async throws -> Status {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        let status: Status
        if set {
            // swiftlint:disable:next force_cast
            status = try await session.perform(MastodonAPI.Statuses.Bookmark(baseURL: baseURL, token: token, id: id)) as! Status
        }
        else {
            // swiftlint:disable:next force_cast
            status = try await session.perform(MastodonAPI.Statuses.Unbookmark(baseURL: baseURL, token: token, id: id)) as! Status
        }
        update(status)
        return status
    }
}

public extension Service {
    // https://mastodon.example/api/v1/statuses
    @available(*, deprecated, message: "Use MastodonAPI directly")
    func postStatus(_ newPost: NewPost) async throws -> Status {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        logger?.log("Posting")
        let url = URL(string: "https://\(host)/api/v1/statuses")!
        var request = URLRequest.post(url)
            .headers(token.headers)
            .headers(["Content-Type": "application/json; charset=utf-8"])
        request.httpBody = try JSONEncoder().encode(newPost)
        let (data, _) = try await session.validatedData(for: request)
        let status = try decoder.decode(Status.self, from: data)
        update(status)
        logger?.log("Posted: \(String(describing: status))")
        return status
    }

    @available(*, deprecated, message: "Use MastodonAPI directly")
    func uploadAttachment(file: URL, description: String) async throws -> MediaAttachment {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        logger?.log("Uploading image")

        let fileData = try Data(contentsOf: file)

        let formValues: [FormValue] = [
            .value("description", description),
            .file("file", file.lastPathComponent, "image/png", fileData), // TODO:
        ]

        let url = URL(string: "https://\(host)/api/v1/media")!
        let request = URLRequest.post(url)
            .headers(token.headers)
            .multipartForm(formValues)

        let (data, _) = try await session.validatedData(for: request)
        let attachment = try decoder.decode(MediaAttachment.self, from: data)
        return attachment
    }
}
