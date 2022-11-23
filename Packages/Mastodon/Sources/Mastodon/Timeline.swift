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
    func fetchPageForTimeline(_ timeline: Timeline) async throws -> Timeline.Page {
        let request = timeline.request(baseURL: baseURL, token: authorization.token!)
        let fetch = Fetch(Status.self, service: self, request: request)
        let page = try await fetch()
        return page
    }

    func fetchTimeline(_ timeline: Timeline) async throws -> Timeline.Content {
        fatalError()
    }

    func updateTimeline(_ timeline: Timeline) async throws -> Timeline.Content {
        fatalError()
    }
}

// MARK: -

public struct Fetch <Element>: FetchProtocol where Element: Codable & Identifiable & Sendable, Element.ID: Comparable & Sendable {
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

struct PageResponse <Element>: Response where Element: Codable & Identifiable, Element.ID: Comparable {
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
        let container = try decoder.singleValueContainer()
        guard let service = decoder.userInfo[CodingUserInfoKey(rawValue: "service")!] as? Service else {
            fatalError("No service set on decoder userinfo.")
        }
        self.service = service
        self.request = nil
    }

    public func encode(to encoder: Encoder) throws {
        // TODO: Only semi codable.
    }
}
