import Foundation

public protocol PagedCursorProtocol {
    associatedtype Next
    associatedtype Previous

    var next: Next? { get }
    var previous: Next? { get }
}

// MARK: -

public enum PagingDirection {
    case previous
    case next
}

// MARK: -

public struct PagedContent <Element, Cursor>: Identifiable where Element: Identifiable, Element.ID: Comparable, Cursor: PagedCursorProtocol {
    public typealias Element = Element
    public typealias Page = Mastodon.Page<Element, Cursor> // TODO: Gross.

    public var id: [ClosedRange<Element.ID>?] {
        return pages.map(\.id)
    }

    public var pages: [Page] {
        willSet {
            // TODO: Make sure new content doesn't overlap old content and handle if it does.
        }
    }
}

public struct Page <Element, Cursor>: Identifiable where Element: Identifiable, Element.ID: Comparable, Cursor: PagedCursorProtocol {
    public typealias Element = Element

    public var elements: [Element] {
        didSet {
            // Make sure any changes to status only change content of statuses and doesn't change order or ids
            assert(oldValue.map(\.id) == elements.map(\.id))
        }
    }

    public let id: ClosedRange<Element.ID>?
    public let cursor: Cursor

    public init(cursor: Cursor, elements: [Element] = []) {
        if let first = elements.first, let last = elements.first {
            self.id = first.id ... last.id
        }
        else {
            self.id = nil
        }
        self.cursor = cursor
        self.elements = elements
    }
}

// MARK: -

public struct URLCursor: PagedCursorProtocol {
    public typealias Next = URL
    public typealias Previous = URL

    public let next: URL?
    public let previous: URL?
}

public typealias StatusesPagedContent = PagedContent<Status, URLCursor>
public typealias StatusPage = StatusesPagedContent.Page
