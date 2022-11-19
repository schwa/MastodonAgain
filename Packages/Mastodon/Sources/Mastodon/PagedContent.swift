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
        assert(elements.map(\.id) == elements.map(\.id).sorted().reversed())
    }
}

// MARK: -

public struct PagedContent<Fetch>: Identifiable, Sendable where Fetch: FetchProtocol {
    public typealias Element = Fetch.Element
    public typealias Page = Mastodon.Page<Fetch> // TODO: Gross.

    public var id: [Page.ID] {
        pages.map(\.id)
    }

    public var pages: [Page] {
        willSet {
            let a = newValue.map(\.id)
            let b = a.sorted().reversed()
            assert(a == Array(b))
            // TODO: Make sure new content doesn't overlap old content and handle if it does.
        }
    }

    public init() {
        pages = []
    }
}

// MARK: -

extension Page<Service.Fetch>.ID: CustomDebugStringConvertible {
    public var debugDescription: String {
        // TODO: Expand this.
        FunHash(self).rawValue
    }
}

extension Page: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Page <\(Element.self)> (id: \(FunHash(id)), previous: \(previous), next: \(next), elements: \(elements.count))"
    }
}
