import CryptoKit
import Foundation
import Support

// MARK: -

public enum PagingDirection: Sendable {
    case previous
    case next
}

// MARK: -

public protocol FetchProtocol: Sendable {
    associatedtype Element where Element: Identifiable & Sendable, Element.ID: Comparable & Sendable

    func callAsFunction() async throws -> Page<Self>
}

// MARK: -

public struct Page<Fetch>: Identifiable, Sendable where Fetch: FetchProtocol {
    public typealias Fetch = Fetch
    public typealias Element = Fetch.Element

    public let id: CompositeHash<Element.ID>
    public let previous: Fetch?
    public let next: Fetch?

    public var elements: [Element] {
        willSet {
            assert(newValue.map(\.id) == newValue.map(\.id).sorted().reversed())
        }
        didSet {
            // Make sure any changes to status only change content of statuses and doesn't change order or ids
            assert(oldValue.map(\.id) == elements.map(\.id))
        }
    }

    public init(previous: Fetch?, next: Fetch?, elements: [Element] = []) {
        id = .init(elements.map(\.id))
        self.previous = previous
        self.next = next
        self.elements = elements
        // ISSUE: https://github.com/schwa/MastodonAgain/issues/46 - make sure elements are in order and unique?
        //assert(elements.map(\.id) == elements.map(\.id).sorted().reversed())
    }
}

// MARK: -

public struct PagedContent<Fetch>: Identifiable, Sendable where Fetch: FetchProtocol {
    public typealias Element = Fetch.Element
    public typealias Page = Mastodon.Page<Fetch>

    public var id: [Page.ID] {
        pages.map(\.id)
    }

    public var pages: [Page]

    public init() {
        pages = []
    }
}

public extension PagedContent {
    var allElements: [Element] {
        pages.flatMap(\.elements)
    }

    func reducePageToFit(_ page: Page) -> Page {
        let allElementIDs = Set(pages.flatMap(\.elements).map(\.id))
        return Page(previous: page.previous, next: page.next, elements: page.elements.filter { !allElementIDs.contains($0.id) })
    }
}

// MARK: -

extension Page: Codable where Fetch: Codable, Element.ID: Codable, Element: Codable {
}

extension PagedContent: Codable where Page: Codable {
}

extension Page: Equatable where Fetch: Equatable, Element.ID: Equatable, Element: Equatable {
}

extension PagedContent: Equatable where Page: Equatable {
}

// MARK: -

extension Page: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Page <\(Element.self)> (id: \(FunHash(id)), previous: \(String(describing: previous)), next: \(String(describing: next)), elements: \(elements.count))"
    }
}
