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
    @available(*, deprecated, message: "Use MastodonAPI directly")
    func postStatus(_ newPost: NewPost) async throws -> Status {
        logger?.log("Posting")
        let status = await try perform { baseURL, token in
            MastodonAPI.Statuses.Publish(baseURL: baseURL, token: token, post: newPost)
        }
        return status
    }

    @available(*, deprecated, message: "Use MastodonAPI directly")
    func uploadAttachmentOld(file: URL, description: String) async throws -> MediaAttachment {
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

    @available(*, deprecated, message: "Use MastodonAPI directly")
    func uploadAttachment(file: URL, description: String) async throws -> MediaAttachment {
        try await perform { baseURL, token in
            TODOMediaUpload(baseURL: baseURL, token: token, description: description, file: file)
        }
    }
}

struct TODOMediaUpload: Request, Response {
    typealias Result = MediaAttachment

    let baseURL: URL
    let token: Token
    let description: String
    let file: URL

    var request: some Request {
        Method.post
        baseURL
        URLPath("/api/v1/media")
        Header(name: "Authorization", value: "Bearer \(token.accessToken)")
        Form {
            FormParameter(name: "description", value: description)
            FormParameter(name: "file", url: file)
        }
    }

    var response: some Response {
        standardResponse(Result.self)
    }
}
