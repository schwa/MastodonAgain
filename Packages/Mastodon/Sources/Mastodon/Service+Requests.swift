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
