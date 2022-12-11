import AsyncAlgorithms
import Blueprint
import Everything
import Foundation
import SwiftUI

// TODO: Refactor this code. Move things else.

public enum Timeline: Codable, Hashable, Sendable {
    public typealias Content = PagedContent<Fetch<Element>>
    public typealias Page = Content.Page
    public typealias Element = Status

    case `public`
    case federated
    case local
    case hashtag(String)
    case home
    case list(Mastodon.List.ID)

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

    public var systemImageName: String {
        // TODO: This icon names are almost random.
        switch self {
        case .public:
            return "globe.europe.africa"
        case .federated:
            return "person.3"
        case .local:
            return "map"
        case .hashtag:
            return "number.circle"
        case .home:
            return "house"
        case .list:
            return "list.bullet.clipboard"
        }
    }

    public var label: some View {
        Label(title, systemImage: systemImageName)
    }

    @RequestBuilder
    func request(baseURL: URL, token: Token) -> some Request {
        switch self {
        case .public:
            MastodonAPI.Timelimes.Public(baseURL: baseURL, token: token)
        case .federated:
            MastodonAPI.Timelimes.Public(baseURL: baseURL, token: token, remote: true)
        case .local:
            MastodonAPI.Timelimes.Public(baseURL: baseURL, token: token, local: true)
        case .hashtag(let hashtag):
            MastodonAPI.Timelimes.Hashtag(baseURL: baseURL, token: token, hashtag: hashtag)
        case .home:
            MastodonAPI.Timelimes.Home(baseURL: baseURL, token: token)
        case .list(let id):
            MastodonAPI.Timelimes.List(baseURL: baseURL, token: token, id: id)
        }
    }
}

