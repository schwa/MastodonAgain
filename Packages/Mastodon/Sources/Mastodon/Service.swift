import AsyncAlgorithms
import Everything
import Foundation
import RegexBuilder
import os
import UniformTypeIdentifiers

private let logger: Logger? = Logger()

public actor Service {
    private var host: String?
    private var token: Token?
    private let session = URLSession.shared
    private let decoder: JSONDecoder

    private var datedStatuses: [Status.ID: Dated<Status>] = [:]
    private var datedAccounts: [Account.ID: Dated<Account>] = [:]

    public init() {
        decoder = JSONDecoder()
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
    }

    public func update(host: String?, token: Token?) {
        self.host = host
        self.token = token
    }

    public func update(_ value: Status) {
        datedStatuses[value.id] = .init(value)
    }

    public func update(_ other: some Collection<Status>) {
        let now = Date.now
        let other = other.map { Dated($0, date: now) }.map { ($0.content.id, $0) }
        datedStatuses.merge(other) { _, rhs in
            rhs
        }
    }

    public func update(_ value: Account) {
        datedAccounts[value.id] = .init(value)
    }
}

public extension Service {
    func status(for id: Status.ID) async -> Status? {
        return datedStatuses[id]?.content
    }

    // TODO: All this needs cleanup. Use URLPath to return a (pre-configured) URLRequest
    func fetchStatus(for id: Status.ID) async throws -> Status {
        guard let host, let token else {
            fatalError("No host or token.")
        }
        // https://mastodon.example/api/v1/statuses/:id
        let url = URL(string: "https://\(host)/api/v1/statuses/\(id.rawValue)")!
        let request = URLRequest(url: url).headers(token.headers)
        let (data, _) = try await session.validatedData(for: request)
        let status = try decoder.decode(Status.self, from: data)
        update(status)
        return status
    }

    func timelime(_ timeline: Timeline, direction: Timeline.Direction? = nil) async throws -> Timeline {
//    https://docs.joinmastodon.org/methods/timelines/

        guard let host, let token else {
            fatalError("No host or token.")
        }

        let url: URL
        switch direction {
        case nil:
            url = timeline.url
        case .previous:
            guard let previous = timeline.previousURL else {
                print("NO PREVIOUS")
                return timeline
            }
            url = previous
        case .next:
            guard let next = timeline.nextURL else {
                print("NO NEXT")
                return timeline
            }
            url = next
        }

        let request = URLRequest(url: url).headers(token.headers)

        let (data, response) = try await session.validatedData(for: request)

        var previous: URL?
        var next: URL?
        if let link = response.allHeaderFields["Link"] {
            let link = link as! String
            let links = try processLinks(string: link)
            print(links)
            previous = links["prev"]
            next = links["next"]
        }

        let statuses = try decoder.decode([Status].self, from: data)
        if statuses.isEmpty {
            return timeline
        }

        update(statuses)
        let page = Timeline.Page(url: url, statuses: statuses, previous: previous, next: next)

        // TODO: Need to sort statuses (or rely on view to do it)
        return Timeline(host: host, timelineType: timeline.timelineType, pages: timeline.pages + [page])
    }

    func favorite(status: Status.ID) async throws -> Status {
        guard let host, let token else {
            fatalError("No host or token.")
        }
        let url = URL(string: "https://\(host)/api/v1/statuses/\(status.rawValue)/favourite")!
        let request = URLRequest.post(url).headers(token.headers)
        let (status, _) = try await session.json(Status.self, decoder: decoder, for: request)
        // TODO: Check response
        update(status)
        return status
    }

    func reblog(status: Status.ID) async throws -> Status {
        guard let host, let token else {
            fatalError("No host or token.")
        }
        let url = URL(string: "https://\(host)/api/v1/statuses/\(status.rawValue)/reblog")!
        let request = URLRequest.post(url).headers(token.headers)
        let (status, _) = try await session.json(Status.self, decoder: decoder, for: request)
        // TODO: Check response
        update(status)
        return status
    }
}

public extension Service {
    // https://mastodon.example/api/v1/statuses
    func postStatus(text: String, inReplyTo: Status.ID?) async throws -> Status {
        guard let host, let token else {
            fatalError("No host or token.")
        }
        logger?.log("Posting")
        let url = URL(string: "https://\(host)/api/v1/statuses")!

        var form = [
            "status": text,
        ]
        if let inReplyTo {
            form["in_reply_to_id"] = inReplyTo.rawValue
        }

        let request = URLRequest.post(url)
            .headers(token.headers)
            .form(form)

        let (data, _) = try await session.validatedData(for: request)
        let status = try decoder.decode(Status.self, from: data)
        update(status)
        logger?.log("Posted: \(String(describing: status))")
        return status
    }

    func uploadAttachment(file: URL, description: String) async throws -> Any {
        guard let host, let token else {
            fatalError("No host or token.")
        }
        logger?.log("Posting")

        let fileData = try Data(contentsOf: file)

        let formValues: [FormValue] = [
            .value("description", description),
            .file("image", file.lastPathComponent, "image/png", fileData) // TODO
        ]

        let url = URL(string: "https://\(host)/api/v1/media")!
        let request = URLRequest.post(url)
            .headers(token.headers)
            .multipartForm(formValues)

        let (data, _) = try await session.validatedData(for: request)

        print(try jsonTidy(data: data))
        return status
    }
}
