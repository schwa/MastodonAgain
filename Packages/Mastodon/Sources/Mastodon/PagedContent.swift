import Foundation

// MARK: -

public enum PagingDirection {
    case previous
    case next
}

// MARK: -

public struct PagedContent <Element>: Identifiable where Element: Identifiable, Element.ID: Comparable {
    public typealias Element = Element
    public typealias Page = Mastodon.Page<Element> // TODO: Gross.
    public typealias Cursor = Page.Cursor

    public var id: [ClosedRange<Element.ID>?] {
        return pages.map(\.id)
    }

    public var pages: [Page] {
        willSet {
            // TODO: Make sure new content doesn't overlap old content and handle if it does.
        }
    }

    public init() {
        self.pages = []
    }
}

public struct Page <Element>: Identifiable where Element: Identifiable, Element.ID: Comparable {
    public typealias Element = Element

    public struct Cursor {
        public typealias Fetch = () async throws -> Page

        public var previous: Fetch?
        public var next: Fetch?

        public init(previous: Fetch? = nil, next: Fetch? = nil) {
            self.previous = previous
            self.next = next
        }
    }

    public let id: ClosedRange<Element.ID>?
    public let cursor: Cursor

    public var elements: [Element] {
        didSet {
            // Make sure any changes to status only change content of statuses and doesn't change order or ids
            assert(oldValue.map(\.id) == elements.map(\.id))
        }
    }

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

extension Page: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Page <\(Element.self)> (id: \(id.map({ String(describing: $0) }) ?? "nil"), cursor: \(cursor), elements: \(elements.count)"
    }
}

extension Page.Cursor: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Page <\(Element.self)>.Cursor()"
    }
}

// MARK: -

public typealias StatusesPagedContent = PagedContent<Status>
public typealias StatusPage = StatusesPagedContent.Page
