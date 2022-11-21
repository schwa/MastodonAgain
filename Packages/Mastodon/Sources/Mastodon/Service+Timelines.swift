import Blueprint
import Everything
import Foundation

public extension Service {
    func fetchStatusesPage(request: some Request, overrideURL: URL? = nil) async throws -> PagedContent<Fetch<Status>>.Page {
        let request = OverrideURLRequest(content: request, overrideURL: overrideURL)
        let response = PageResponse<Status>()
        let page = try await perform(request: request, response: response)
        return page
   }

    func timelime(_ timeline: Timeline) async throws -> PagedContent<Fetch<Status>>.Page {
        try await fetchStatusesPage(request: timeline.request(baseURL: baseURL, token: authorization.token!))
    }
}

public struct Fetch <Element>: FetchProtocol, Codable, Hashable where Element: Identifiable & Sendable, Element.ID: Comparable & Sendable {
    let service: Service?
    let url: URL

    init(service: Service?, url: URL) {
        self.service = service
        self.url = url
    }

    public func callAsFunction() async throws -> Page<Self> {
//        try await service.fetchStatusesPage(request: xxxx, overrideURL: url)
        fatalError()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let service = decoder.userInfo[CodingUserInfoKey(rawValue: "service")!] as? Service else {
            fatalError("No service set on decoder userinfo.")
        }
        self.service = service
        url = try container.decode(URL.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(url)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
        url.hash(into: &hasher)
    }
}

struct OverrideURLRequest<Content>: Request where Content: Request {
    let content: Content
    let overrideURL: URL?

    var request: some Request {
        content
        overrideURL
    }
}

struct PageResponse <Element>: Response where Element: Codable & Identifiable, Element.ID: Comparable {
    typealias Result = Page<Fetch<Element>>

    var response: some Response {
        IfStatus(200) { data, response -> Result in
            let elements = try JSONDecoder.mastodonDecoder.decode([Element].self, from: data)
            var previous: Fetch<Element>?
            var next: Fetch<Element>?
            guard let response = response as? HTTPURLResponse else {
                fatalError("Could not get HTTPURLResponse.") // TODO: Why bother with URLResponse at all any more?
            }
            if let link = response.allHeaderFields["Link"] {
                // swiftlint:disable:next force_cast
                let link = link as! String
                let links = try processLinks(string: link)
                if let url = links["prev"] {
                    previous = Fetch<Element>(service: nil, url: url)
                }
                if let url = links["next"] {
                    next = Fetch<Element>(service: nil, url: url)
                }
            }
            return Page(previous: previous, next: next, elements: elements)
        }
    }
}

