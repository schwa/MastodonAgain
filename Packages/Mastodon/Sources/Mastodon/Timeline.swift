import Foundation

public enum TimelineType: Codable, Equatable {
    case `public`
    case federated
    case local
    case hashtag(String)
    case home
    case list(String) // List.ID
    case canned

    public var path: URLPath? {
        switch self {
        case .public:
            return "/api/v1/timelines/public" // TODO: these urls may be wrong
        case .federated:
            return "/api/v1/timelines/public?remote=true" // TODO: these urls may be wrong
        case .local:
            return "/api/v1/timelines/public?local=true" // TODO: these urls may be wrong
        case .hashtag(let hashtag):
            return "/api/v1/timelines/tag/\(hashtag)"
        case .home:
            return "/api/v1/timelines/home"
        case .list(let list):
            return "/api/v1/timelines/list/\(list)"
        case .canned:
            return nil
        }
    }

    public var title: String {
        switch self {
        case .public:
            return "Public"
        case .federated:
            return "Federated"
        case .local:
            return "Local"
        case .hashtag(let hashtag):
            return "#\(hashtag)"
        case .home:
            return "Home"
        case .list(let listID):
            return "List(\(listID))"
        case .canned:
            return "Canned"
        }
    }
}

// MARK: -

public enum PagingDirection {
    case previous
    case next
}

public struct Timeline: Codable {
    public typealias Page = TimelinePage
    public typealias Direction = PagingDirection

    public var url: URL? {
        timelineType.path.map { URL(string: "https://\(host)\($0)")! }
    }

    public let timelineType: TimelineType
    public var host: String

    // TODO: it is possible pages within timelimes can overlap - giving us duplicate statuses we need to guard against that.
    public var pages: [Page] {
        didSet {
            assert(oldValue.map(\.id) == pages.map(\.id))
        }
    }

    public init(host: String, timelineType: TimelineType, canned: Bool = false, pages: [Page] = []) {
        self.host = host
        self.timelineType = timelineType
        self.pages = pages
    }
}

extension Timeline: CustomStringConvertible {
    public var description: String {
        String("Timeline(timelineType: \(timelineType), pages: \(pages.count)")
    }
}

public extension Timeline {
    var previousURL: URL? {
        guard let first = pages.first else {
            return nil
        }

        if let url = first.previous {
            return url
        }
        else {
            guard let url = url else {
                return nil
            }
            return url.appending(queryItems: [
                .init(name: "since_id", value: first.statuses.first!.id.rawValue)
            ])
        }
    }

    var nextURL: URL? {
        pages.last?.next
    }
}

// MARK: -

public struct TimelinePage: Identifiable, Codable {
    public let id: String
    public let url: URL
    public var statuses: [Status] {
        didSet {
            // Make sure any changes to status only change content of statuses and doesn't change order or ids
            assert(oldValue.map(\.id) == statuses.map(\.id))
        }
    }
    public let previous: URL?
    public let next: URL?
    public let data: Data?

    init(url: URL, statuses: [Status] = [], previous: URL? = nil, next: URL? = nil, data: Data? = nil) {
        assert(statuses.first!.id >= statuses.last!.id)
        self.id = "\(url) | \(statuses.count)\(statuses.first!.id) -> \(statuses.last!.id)"
        self.url = url
        self.statuses = statuses
        self.previous = previous
        self.next = next
        self.data = data
    }
}
