import Blueprint
import Everything
import Foundation

public extension Service {
    func timelime(_ timeline: Timeline) async throws -> PagedContent<Fetch<Status>>.Page {
        let request = timeline.request(baseURL: baseURL, token: authorization.token!)
        let fetch = Fetch(Status.self, service: self, request: request)
        return try await fetch()
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
            guard let response = response as? HTTPURLResponse else {
                fatalError("Could not get HTTPURLResponse.") // TODO: Why bother with URLResponse at all any more?
            }
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


// TODO: We want to make Fetch Codable so we can make Timeline PagedContent Codable so we can cache these.

//extension Fetch: Hashable {
//    public static func == (lhs: Self, rhs: Self) -> Bool {
//        lhs.url == rhs.url
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        url.hash(into: &hasher)
//    }
//}

extension Fetch: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let service = decoder.userInfo[CodingUserInfoKey(rawValue: "service")!] as? Service else {
            fatalError("No service set on decoder userinfo.")
        }
        self.service = service
        self.request = nil
    }

    public func encode(to encoder: Encoder) throws {
    }
}
