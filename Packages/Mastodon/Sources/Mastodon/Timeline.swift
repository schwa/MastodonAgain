import AsyncAlgorithms
import Blueprint
import Everything
import Foundation
import SwiftUI

// TODO: Refactor this code. Move things else.

public enum Timeline: Codable, Hashable, Sendable {
    public typealias Content = PagedContent<Fetch<Element>>
    public typealias Page = Content.Page
    public typealias Element = Status

    case `public`
    case federated
    case local
    case hashtag(String)
    case home
    case list(Mastodon.List.ID)

    @available(*, deprecated, message: "Use MastodonAPI instead.")
    public var path: URLPath? {
        switch self {
        case .public:
            return "/api/v1/timelines/public" // TODO: these urls may be wrong
        case .federated:
            return "/api/v1/timelines/public?remote=true" // TODO: these urls may be wrong
        case .local:
            return "/api/v1/timelines/public?local=true" // TODO: these urls may be wrong
        case .hashtag(let hashtag):
            return "/api/v1/timelines/tag/\(hashtag)"
        case .home:
            return "/api/v1/timelines/home"
        case .list(let list):
            return "/api/v1/timelines/list/\(list)"
        }
    }

    public var title: String {
        switch self {
        case .public:
            return "Public"
        case .federated:
            return "Federated"
        case .local:
            return "Local"
        case .hashtag(let hashtag):
            return "#\(hashtag)"
        case .home:
            return "Home"
        case .list(let listID):
            return "List(\(listID))"
        }
    }

    public var systemImageName: String {
        // TODO: This icon names are almost random.
        switch self {
        case .public:
            return "globe.europe.africa"
        case .federated:
            return "person.3"
        case .local:
            return "map"
        case .hashtag:
            return "number.circle"
        case .home:
            return "house"
        case .list:
            return "list.bullet.clipboard"
        }
    }

    public var image: Image {
        Image(systemName: systemImageName)
    }

    @RequestBuilder
    func request(baseURL: URL, token: Token) -> some Request {
        switch self {
        case .public:
            MastodonAPI.Timelimes.Public(baseURL: baseURL, token: token)
        case .federated:
            MastodonAPI.Timelimes.Public(baseURL: baseURL, token: token, remote: true)
        case .local:
            MastodonAPI.Timelimes.Public(baseURL: baseURL, token: token, local: true)
        case .hashtag(let hashtag):
            MastodonAPI.Timelimes.Hashtag(baseURL: baseURL, token: token, hashtag: hashtag)
        case .home:
            MastodonAPI.Timelimes.Home(baseURL: baseURL, token: token)
        case .list(let id):
            MastodonAPI.Timelimes.List(baseURL: baseURL, token: token, id: id)
        }
    }
}

public extension Service {
    // TODO: Would love to 'Element' go away here.
    func broadcaster<Element>(for key: BroadcasterKey, element: Element.Type) -> AsyncChannelBroadcaster<Element> where Element: Sendable {
        let broadcaster = broadcasters[key, default: AnyAsyncChannelBroadcaster(AsyncChannelBroadcaster<Element>())]
        broadcasters[key] = broadcaster
        // swiftlint:disable:next force_cast
        return broadcaster.base as! AsyncChannelBroadcaster<Element>
    }

    func fetchPageForTimeline(_ timeline: Timeline) async throws {
        Task {
            var content = storage[timeline] ?? Timeline.Content()
            await broadcaster(for: .timeline(timeline), element: Timeline.Content.self).broadcast(content)

            let request = timeline.request(baseURL: baseURL, token: authorization.token!)
            let fetch = Fetch(Status.self, service: self, request: request)
            let page = try await fetch()
            guard !content.pages.contains(where: { $0.id == page.id }) else {
                logger?.log("Paged content already contains page \(FunHash(page.id).description)")
                return content
            }

            try await fetchRelationships(ids: page.elements.map(\.account.id))

            // TODO:
            // https://github.com/schwa/MastodonAgain/issues/46
            // We need to make sure all pages are in the correct order.
            // We need to make sure all pages are unique
            // We need to make sure no elements appear twice

            let reducedPage = content.reducePageToFit(page)
            content.pages.insert(reducedPage, at: 0)
            storage[timeline] = content
            await broadcaster(for: .timeline(timeline), element: Timeline.Content.self).broadcast(content)
            return content
        }
    }
}

// MARK: -

public struct Fetch<Element>: FetchProtocol where Element: Codable & Identifiable & Sendable, Element.ID: Comparable & Sendable {
    let service: Service?
    let request: (any Request)?

    public init(_ elementType: Element.Type, service: Service? = nil, request: (any Request)?) {
        self.service = service
        self.request = request
    }

    public func callAsFunction() async throws -> Page<Self> {
        guard let service, let request else {
            // TODO: Log this.
            return Page(previous: nil, next: nil, elements: [])
        }
        let response = PageResponse<Element> { url in
            let request = OverrideURLRequest(content: request, overrideURL: url)
            let fetch = Fetch(Element.self, service: service, request: request)
            return fetch
        }
        let page = try await service.perform(request: request, response: response)
        return page
    }
}

// MARK: -

struct PageResponse<Element>: Response where Element: Codable & Identifiable, Element.ID: Comparable {
    typealias Result = Page<Fetch<Element>>

    let fetchForURL: (URL) -> Fetch<Element>?

    var response: some Response {
        IfStatus(200) { data, response -> Result in
            let elements = try JSONDecoder.mastodonDecoder.decode([Element].self, from: data)
            var previous: Fetch<Element>?
            var next: Fetch<Element>?
            if let link = response.allHeaderFields["Link"] {
                // swiftlint:disable:next force_cast
                let link = link as! String
                let links = try processLinks(string: link)
                if let url = links["prev"] {
                    previous = fetchForURL(url)
                }
                if let url = links["next"] {
                    next = fetchForURL(url)
                }
            }
            return Page(previous: previous, next: next, elements: elements)
        }
    }
}

extension Fetch: Codable {
    public init(from decoder: Decoder) throws {
        // TODO: Only semi codable.
//        let container = try decoder.singleValueContainer()
//        guard let service = decoder.userInfo[CodingUserInfoKey(rawValue: "service")!] as? Service else {
//            fatalError("No service set on decoder userinfo.")
//        }
        service = nil
        request = nil
    }

    public func encode(to encoder: Encoder) throws {
        // TODO: Only semi codable.
    }
}

// MARK: -

public extension Service {
    // TODO: String keys.

    func fetchAllKnownRelationships() async throws {
        let relationships = storage["relationships"] ?? [Account.ID: Relationship]()
        await broadcaster(for: .relationships, element: [Account.ID: Relationship].self).broadcast(relationships)
    }

    func fetchRelationships(ids: [Account.ID], remoteOnly: Bool = false) async throws {
        // De-dupe input.
        let ids = Array(Set(ids))
        // We're gonna be broadcasting the shit out of these relationships.
        let broadcaster = broadcaster(for: .relationships, element: [Account.ID: Relationship].self)
        let storedRelationships = storage["relationships"] ?? [Account.ID: Relationship]()
        if !remoteOnly {
            // Get relationships we already know about that match input and broadcast them.
            let relationships = storedRelationships.filter({ ids.contains($0.key) })
            if !relationships.isEmpty {
                await broadcaster.broadcast(relationships)
            }
        }
        Task {
            // Fetch relationships from server.
            let newRelationships = try await perform { baseURL, token in
                MastodonAPI.Accounts.Relationships(baseURL: baseURL, token: token, ids: ids)
            }
            // Merge all new relationships with all stored relationships
            let allRelationships = storedRelationships.merging(zip(newRelationships.map(\.id), newRelationships)) { _, rhs in
                rhs
            }
            // Broadcast all relationships that match input
            let filteredRelationships = allRelationships.filter({ ids.contains($0.key) })
            if !filteredRelationships.isEmpty {
                await broadcaster.broadcast(filteredRelationships)
            }
            // Save all relationships to disk
            await MainActor.run {
                storage["relationships"] = allRelationships
            }
        }
    }
}
