import Blueprint
import Foundation
import SwiftUI

public enum TimelineType: Codable, Hashable, Sendable {
    case `public`
    case federated
    case local
    case hashtag(String)
    case home
    case list(String) // List.ID

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
        }
    }

    public var image: Image {
        // TODO: This icon names are almost random.
        switch self {
        case .public:
            return Image(systemName: "globe.europe.africa")
        case .federated:
            return Image(systemName: "person.3")
        case .local:
            return Image(systemName: "map")
        case .hashtag:
            return Image(systemName: "number.circle")
        case .home:
            return Image(systemName: "house")
        case .list:
            return Image(systemName: "list.bullet.clipboard")
        }
    }
}

// MARK: -

public struct Timeline: Codable, Hashable, Sendable {
    public var url: URL? {
        timelineType.path.map { URL(string: "https://\(host)\($0)")! }
    }

    public let host: String
    public let timelineType: TimelineType

    public init(host: String, timelineType: TimelineType) {
        self.host = host
        self.timelineType = timelineType
    }
}
