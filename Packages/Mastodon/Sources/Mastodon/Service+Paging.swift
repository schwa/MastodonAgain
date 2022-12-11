import AsyncAlgorithms
import Blueprint
import Everything
import Foundation
import SwiftUI

public extension Service {
    func fetchPageForTimeline(_ timeline: Timeline) async throws {
        Task {
            var content = try await storage.get(key: timeline) ?? Timeline.Content()
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
            try await storage.set(key: timeline, value: content)
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
        // TODO: This should be part of MastodonAPI not added here? Maybe?
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
