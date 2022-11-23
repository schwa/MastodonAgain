import AsyncAlgorithms
import Blueprint
import Everything
import Foundation
import SwiftUI

public enum TimelineType: Codable, Hashable, Sendable {
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

    public var image: Image {
        // TODO: This icon names are almost random.
        switch self {
        case .public:
            return Image(systemName: "globe.europe.africa")
        case .federated:
            return Image(systemName: "person.3")
        case .local:
            return Image(systemName: "map")
        case .hashtag:
            return Image(systemName: "number.circle")
        case .home:
            return Image(systemName: "house")
        case .list:
            return Image(systemName: "list.bullet.clipboard")
        }
    }
}

// MARK: -

public struct Timeline: Codable, Hashable, Sendable {
    public let host: String
    public let timelineType: TimelineType

    public init(host: String, timelineType: TimelineType) {
        self.host = host
        self.timelineType = timelineType
    }

    public typealias Content = PagedContent<Fetch<Element>>
    public typealias Page = Content.Page
    public typealias Element = Status
}

extension Timeline {
    @RequestBuilder
    func request(baseURL: URL, token: Token) -> some Request {
        switch timelineType {
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
    func channel(for timeline: Timeline) -> AsyncChannel<Timeline.Content> {
        if let channel = channels[timeline] as? AsyncChannel<Timeline.Content> {
            return channel
        }
        else {
            let channel = AsyncChannel<Timeline.Content>()
            channels[timeline] = channel
            return channel
        }
    }

    func fetchPageForTimeline(_ timeline: Timeline) async throws {
        Task {
            var content = storage[timeline] ?? Timeline.Content()
            await channel(for: timeline).send(content)

            let request = timeline.request(baseURL: baseURL, token: authorization.token!)
            let fetch = Fetch(Status.self, service: self, request: request)
            let page = try await fetch()
            guard !content.pages.contains(where: { $0.id == page.id }) else {
                logger?.log("Paged content already contains page \(FunHash(page.id).description)")
                return content
            }

            try await fetchRelationship(ids: page.elements.map(\.account.id))

            // TODO:
            // We need to make sure all pages are in the correct order.
            // We need to make sure all pages are unique
            // We need to make sure no elements appear twice

            let reducedPage = content.reducePageToFit(page)
            content.pages.insert(reducedPage, at: 0)
            storage[timeline] = content
            await channel(for: timeline).send(content)

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

    func relationshipChannel() -> AsyncChannel<[Account.ID: Relationship]> {
        // TODO:
        if let channel = channels["relationships"] as? AsyncChannel<[Account.ID: Relationship]> {
            return channel
        }
        else {
            let channel = AsyncChannel<[Account.ID: Relationship]>()
            channels["relationship"] = channel
            return channel
        }
    }

    func fetchRelationship() async throws {
        let relationships = storage["relationships"] ?? [Account.ID: Relationship]()
        logger?.log("XX: Fetched \(relationships.count) relationships from storage")
        await relationshipChannel().send(relationships)
    }

    func fetchRelationship(ids: [Account.ID]) async throws {
        let storedRelationships = storage["relationships"] ?? [Account.ID: Relationship]()
        logger?.log("XX: Fetched \(storedRelationships.count) relationships from storage")

        let relationships = storedRelationships.filter({ ids.contains($0.key) })
        if !relationships.isEmpty {
            logger?.log("XX: Sending \(relationships.count) relationships.")
            await relationshipChannel().send(relationships)
        }

        Task {
            // Dedupe.
            let ids = Array(Set(ids))
            logger?.log("XX: Fetching \(ids.count) relationships")
            let relationships = try await perform { baseURL, token in
                MastodonAPI.Accounts.Relationships(baseURL: baseURL, token: token, ids: ids)
            }
            let allRelationships = storedRelationships.merging(zip(relationships.map(\.id), relationships)) { _, rhs in
                rhs
            }
            await MainActor.run {
                logger?.log("XX: Storing \(allRelationships.count) relationships.")
                storage["relationships"] = allRelationships
            }

            let filteredRelationships = storedRelationships.filter({ ids.contains($0.key) })
            if !filteredRelationships.isEmpty {
                logger?.log("XX: Sending \(filteredRelationships.count) relationships.")
                await relationshipChannel().send(filteredRelationships)
            }
        }
    }
}
