import Blueprint
import Everything
import Foundation

public extension Service {
    // TODO: This will have to become generic for generic pagedcontentviews
    struct Fetch: FetchProtocol, Codable, Hashable {
        public typealias Element = Status

        let service: Service
        let url: URL

        init(service: Service, url: URL) {
            self.service = service
            self.url = url
        }

        public func callAsFunction() async throws -> Page<Self> {
            // try await service.fetchStatusesPage(url: url)
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

        public static func == (lhs: Service.Fetch, rhs: Service.Fetch) -> Bool {
            lhs.url == rhs.url
        }

        public func hash(into hasher: inout Hasher) {
            url.hash(into: &hasher)
        }
    }

    // TODO: this seems totally generic.
    private func fetchStatusesPage(request: some Request, overrideURL: URL? = nil) async throws -> PagedContent<Fetch>.Page {
        let request = ModifiedRequest(content: request, overrideURL: overrideURL)

        let result = await try perform(request: request, response: LinkedResponse())

        //        let page = PagedContent<Fetch>.Page(previous: nil, next: nil, elements: statuses)
//        //storage[PagedContent<Fetch>.Page.self, page.id] = page
//        return page

//        guard let token = authorization.token else {
//            fatalError("No host or token.")
//        }
//        assert(host == url.host)
//        let request = URLRequest(url: url).headers(token.headers)
//        let (data, response) = try await session.validatedData(for: request)
//
//        let statuses = try decoder.decode([Status].self, from: data)
//
//        // TODO: Are all empty statuses the same even if they have different Cursors?
//
//        var previous: Fetch?
//        var next: Fetch?
//
//        if let link = response.allHeaderFields["Link"] {
//            // swiftlint:disable:next force_cast
//            let link = link as! String
//            let links = try processLinks(string: link)
//            if let url = links["prev"] {
//                previous = Fetch(service: self, url: url)
//            }
//            if let url = links["next"] {
//                next = Fetch(service: self, url: url)
//            }
//        }
//        update(statuses)
//
//        let page = PagedContent<Fetch>.Page(previous: previous, next: next, elements: statuses)
//        //storage[PagedContent<Fetch>.Page.self, page.id] = page
//        return page
        fatalError()
    }

    func timelime(_ timeline: Timeline) async throws -> PagedContent<Fetch>.Page {
        try await fetchStatusesPage(request: timeline.request(baseURL: baseURL, token: authorization.token!))
    }
}

struct ModifiedRequest<Content>: Request where Content: Request {
    let content: Content
    let overrideURL: URL?

    var request: some Request {
        content
        overrideURL
    }
}

struct LinkedResponse: Response {
    var response: some Response {
        IfStatus(200) { data, response -> ([Status], StatusFetch?, StatusFetch?) in
            let result = try JSONDecoder.mastodonDecoder.decode([Status].self, from: data)
            var previous: StatusFetch?
            var next: StatusFetch?
            guard let response = response as? HTTPURLResponse else {
                fatalError()
            }
            if let link = response.allHeaderFields["Link"] {
                // swiftlint:disable:next force_cast
                let link = link as! String
                let links = try processLinks(string: link)
                if let url = links["prev"] {
                    previous = StatusFetch(url: url)
                }
                if let url = links["next"] {
                    next = StatusFetch(url: url)
                }
            }
            return (result, previous, next)
        }
    }
}

public struct StatusFetch: FetchProtocol, Codable, Hashable {
    public typealias Element = Status

    let url: URL

    init(url: URL) {
        self.url = url
    }

    public func callAsFunction() async throws -> Page<Self> {
        // try await service.fetchStatusesPage(url: url)
        fatalError()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
//        guard let service = decoder.userInfo[CodingUserInfoKey(rawValue: "service")!] as? Service else {
//            fatalError("No service set on decoder userinfo.")
//        }
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
