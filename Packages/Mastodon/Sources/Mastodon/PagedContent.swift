import Foundation
import CryptoKit

// MARK: -

public enum PagingDirection: Sendable {
    case previous
    case next
}

// MARK: -

public struct PagedContent <Element>: Identifiable, Sendable where Element: Identifiable & Sendable, Element.ID: Comparable & Sendable {
    public typealias Element = Element
    public typealias Page = Mastodon.Page<Element> // TODO: Gross.
    public typealias Cursor = Page.Cursor

    public var id: [Page.ID] {
        return pages.map(\.id)
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
        self.pages = []
    }
}

public struct Page <Element>: Identifiable, Sendable where Element: Identifiable & Sendable, Element.ID: Comparable & Sendable {
    public typealias Element = Element

    public struct Cursor: Sendable {
        public typealias Fetch = @Sendable () async throws -> Page

        public var previous: Fetch?
        public var next: Fetch?

        public init(previous: Fetch? = nil, next: Fetch? = nil) {
            self.previous = previous
            self.next = next
        }
    }

    public struct ID: Hashable, Comparable, Sendable {
        private let ids: [Element.ID]

        internal init(_ elements: [Element]) {
            ids = elements.map(\.id)
        }

        public static func < (lhs: ID, rhs: ID) -> Bool {
            let lhs = lhs.ids.map(String.init(describing:)).joined(separator: ",")
            let rhs = rhs.ids.map(String.init(describing:)).joined(separator: ",")
            return lhs < rhs
        }
    }

    public let id: ID
    public let cursor: Cursor

    public var elements: [Element] {
        willSet {
            assert(newValue.map(\.id) == newValue.map(\.id).sorted().reversed())
        }
        didSet {
            // Make sure any changes to status only change content of statuses and doesn't change order or ids
            assert(oldValue.map(\.id) == elements.map(\.id))
        }
    }

    public init(cursor: Cursor, elements: [Element] = []) {
        self.id = .init(elements)
        self.cursor = cursor
        self.elements = elements
        assert(elements.map(\.id) == elements.map(\.id).sorted().reversed())
    }
}

extension Page: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Page <\(Element.self)> (id: \(id), cursor: \(cursor), elements: \(elements.count))"
    }
}

extension Page.Cursor: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Cursor(previous: \(previous != nil), next: \(next != nil))"
    }
}

// MARK: -

extension Page<Status>.ID: CustomDebugStringConvertible {
    public var debugDescription: String {
//        let hash = SHA256.hash(data: Array(ids.utf8)).map({ ("0" + String($0, radix: 16)).suffix(2) }).joined()
//        return "\(hash.prefix(8))…\(hash.suffix(8))"
//        return "\(hash.prefix(8))…\(hash.suffix(8))"

        let h = self.hashValue
        return funHash(h)

        //        if let first = ids.first, let last = ids.last {
//            return "\(first)…\(last)"
//        }
//        else {
//            return "<empty>"
//        }
    }
}
