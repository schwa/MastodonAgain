import Everything
import Foundation

public extension Service {
    // TODO: This will have to become generic for generic pagedcontentviews
    struct Fetch: FetchProtocol {
        public typealias Element = Status

        let service: Service
        let url: URL

        init(service: Service, url: URL) {
            self.service = service
            self.url = url
        }

        public func callAsFunction() async throws -> Page<Self> {
            try await service.fetchStatusesPage(url: url)
        }
    }

    // TODO: this seems totally generic.
    private func fetchStatusesPage(url: URL) async throws -> PagedContent<Fetch>.Page {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        assert(host == url.host)
        let request = URLRequest(url: url).headers(token.headers)
        let (data, response) = try await session.validatedData(for: request)

        let statuses = try decoder.decode([Status].self, from: data)

        // TODO: Are all empty statuses the same even if they have different Cursors?

        var previous: Fetch?
        var next: Fetch?

        if let link = response.allHeaderFields["Link"] {
            // swiftlint:disable:next force_cast
            let link = link as! String
            let links = try processLinks(string: link)
            if let url = links["prev"] {
                previous = Fetch(service: self, url: url)
            }
            if let url = links["next"] {
                next = Fetch(service: self, url: url)
            }
        }
        update(statuses)
        return .init(previous: previous, next: next, elements: statuses)
    }

    func timelime(_ timeline: Timeline) async throws -> PagedContent<Fetch>.Page {
        guard let url = timeline.url else {
            fatalError("No url")
        }
        return try await fetchStatusesPage(url: url)
    }
}
