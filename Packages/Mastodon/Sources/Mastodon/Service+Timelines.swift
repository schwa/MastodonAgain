import Foundation

public extension Service {
    private func fetchStatusesPage(url: URL) async throws -> PagedContent<Status>.Page {
        guard let instance = instance, let token = instance.token else {
            fatalError("No instance or token.")
        }
        assert(instance.host == url.host)
        let request = URLRequest(url: url).headers(token.headers)
        let (data, response) = try await session.validatedData(for: request)

        let statuses = try decoder.decode([Status].self, from: data)

        // TODO: Are all empty statuses the same even if they have different Cursors?
        var cursor = PagedContent<Status>.Page.Cursor()
        if let link = response.allHeaderFields["Link"] {
            let link = link as! String
            let links = try processLinks(string: link)
            if let previous = links["prev"] {
                cursor.previous = {
                    try await self.fetchStatusesPage(url: previous)
                }
            }
            if let next = links["next"] {
                cursor.next = {
                    try await self.fetchStatusesPage(url: next)
                }
            }
        }
        update(statuses)
        return .init(cursor: cursor, elements: statuses)
    }

    func timelime(_ timeline: Timeline) async throws -> PagedContent<Status>.Page {
        guard let url = timeline.url else {
            fatalError("No url")
        }
        return try await fetchStatusesPage(url: url)
    }
}
