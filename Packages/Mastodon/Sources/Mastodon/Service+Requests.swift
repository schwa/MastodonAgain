import AsyncAlgorithms
import Blueprint
import Everything
import Foundation
import os
import RegexBuilder
import SwiftUI
import UniformTypeIdentifiers

public extension Service {
    @available(*, deprecated, message: "Use MastodonAPI directly")
    func status(for id: Status.ID) async -> Status? {
        storage[id.rawValue, Dated<Status>.self]?.content
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
