import Everything
import Foundation

public struct Poll: Codable {
}

public struct Card_: Codable {

    public enum CodingKeys: String, CodingKey {
        case authorName = "author_name"
        case authorURL = "author_url"
        case blurhash
        case description
        case embedURL = "embed_url"
//        case height
        case html
        case image
        case providerName = "provider_name"
        case providerURL = "provider_url"
        case title
        case type
        case url
//        case width
    }

//    enum CardType: String, Codable {
//        case link
//    }

    let authorName: String?
    let authorURL: String?
    let blurhash: String?
    let description: String?
    let embedURL: String?
//    let height: Double?
    let html: String?
    let image: String?
    let providerName: String?
    let providerURL: String?
    let title: String?
    let type: String?
    let url: URL?
//    let width: Double?
}

public typealias Card = PlaceholderCodable

public struct Field: Codable {
    public enum CodingKeys: String, CodingKey {
        case name
        case value
        case verifiedAt = "verified_at"
    }

    public let name: String
    public let value: String
    public let verifiedAt: String?
}

public struct Emoji: Codable {
    public enum CodingKeys: String, CodingKey {
        case shortCode
        case url
        case staticURL = "static_url"
        case visibleInPic = "visible_in_pic"
    }

    public let shortCode: String?
    public let url: URL?
    public let staticURL: URL
    public let visibleInPic: Bool?
}

public struct Account: Identifiable, Codable {
    public enum CodingKeys: String, CodingKey {
        case id
        case username
        case acct
        case displayName = "display_name"
        case locked
        case bot
        case discoverable
        case group
        case created = "created_at"
        case note
        case url
        case avatar
        case avatarStatic = "avatar_static"
        case header
        case headerStatic = "header_static"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case statusesCount = "statuses_count"
        case lastStatusAt = "last_status_at"
        case noindex
        case emojis
        case fields
    }

    public let id: Tagged<Account, String>
    public let username: String
    public let acct: String
    public let displayName: String
    public let locked: Bool
    public let bot: Bool
    public let discoverable: Bool?
    public let group: Bool
    public let created: Date
    public let note: String
    public let url: String?
    public let avatar: URL
    public let avatarStatic: URL
    public let header: String
    public let headerStatic: String
    public let followersCount: Int
    public let followingCount: Int
    public let statusesCount: Int
    public let lastStatusAt: Date
    public let noindex: Bool?
    public let emojis: [Emoji]
    public let fields: [Field]
}

public struct Tag: Codable {
    public let name: String
    public let url: URL
}

public struct Application: Codable {
    public let name: String
    public let website: String?
}

public struct RegisteredApplication: Identifiable, Codable, Equatable {
    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case website
        case redirectURI = "redirect_uri"
        case clientID = "client_id"
        case clientSecret = "client_secret"
        case vapidKey = "vapid_key"
    }

    public let id: Tagged<RegisteredApplication, String>
    public let name: String
    public let website: String
    public let redirectURI: String
    public let clientID: String
    public let clientSecret: String
    public let vapidKey: String
}

public struct MediaAttachment: Identifiable, Codable {
    public enum CodingKeys: String, CodingKey {
        case id
        case type
        case url
        case previewURL = "preview_url"
        case remoteURL = "remote_url"
        case previewRemoteURL = "preview_remote_url"
        case textURL = "text_url"
        case meta
        case description
        case blurHash
    }

    public enum MediaType: String, Codable {
        case image
        case audio
        case gifv
        case video
        case unknown
    }

    public struct Meta: Codable {
        public struct Size: Codable {
            public let width: Double?
            public let height: Double?
            public let size: String?
            public let aspect: Double?
        }

        public let original: Size?
        public let small: Size?
    }

    public let id: Tagged<MediaAttachment, String>
    public let type: MediaType
    public let url: URL
    public let previewURL: URL?
    public let remoteURL: URL?
    public let previewRemoteURL: URL?
    public let textURL: URL?
    public let meta: Meta?
    public let description: String?
    public let blurHash: String?
}

public struct Mention: Identifiable, Codable {
    public enum CodingKeys: String, CodingKey {
        case id
        case username
        case url
        case acct
    }

    public let id: Tagged<Mention, String>
    public let username: String
    public let url: URL
    public let acct: String
}

public protocol StatusProtocol {
    var id: Tagged<Status, String> { get }
    var created: Date { get }
    var inReplyToId: Status.ID? { get }
    var inReplyToAccountId: Account.ID? { get }
    var sensitive: Bool { get }
    var spoilerText: String { get }
    var visibility: Status.Visibility { get }
    var language: String? { get }
    var uri: String? { get }
    var url: URL? { get }
    var repliesCount: Int { get }
    var reblogsCount: Int { get }
    var favouritesCount: Int { get }
    var editedAt: Date? { get }
    var content: String { get }
    var application: Application? { get }
    var account: Account { get }
    var mediaAttachments: [MediaAttachment] { get }
    var mentions: [Mention] { get }
    var tags: [Tag] { get }
    var emojis: [Emoji] { get }
    var card: Card? { get }
    var poll: Poll? { get }
    var favourited: Bool? { get }
    var reblogged: Bool? { get }
    var muted: Bool? { get }
    var bookmarked: Bool? { get }
}

public struct Status: StatusProtocol, Identifiable, Codable {
    public enum CodingKeys: String, CodingKey {
        case id
        case created = "created_at"
        case inReplyToId = "in_reply_to_id"
        case inReplyToAccountId = "in_reply_to_account_id"
        case sensitive
        case spoilerText = "spoiler_text"
        case visibility
        case language
        case uri
        case url
        case repliesCount = "replies_count"
        case reblogsCount = "reblogs_count"
        case favouritesCount = "favourites_count"
        case editedAt = "edited_at"
        case content
        case reblog
        case application
        case account
        case mediaAttachments = "media_attachments"
        case mentions
        case tags
        case emojis
        case card
        case poll
        case text
        case favourited
        case reblogged
        case muted
        case bookmarked
    }

    public enum Visibility: String, Codable {
        case `public`
        case unlisted
        case `private`
        case direct
    }

    public let id: Tagged<Status, String>
    public let created: Date
    public let inReplyToId: Status.ID?
    public let inReplyToAccountId: Account.ID?
    public let sensitive: Bool
    public let spoilerText: String
    public let visibility: Visibility
    public let language: String?
    public let uri: String?
    public let url: URL?
    public let repliesCount: Int
    public let reblogsCount: Int
    public let favouritesCount: Int
    public let editedAt: Date?
    public let content: String
    public let reblog: ReblogStatus?
    public let application: Application?
    public let account: Account
    public let mediaAttachments: [MediaAttachment]
    public let mentions: [Mention]
    public let tags: [Tag]
    public let emojis: [Emoji]
    public let card: Card?
    public let poll: Poll?

    public let text: String?
    public let favourited: Bool?
    public let reblogged: Bool?
    public let muted: Bool?
    public let bookmarked: Bool?
}

public struct ReblogStatus: StatusProtocol, Identifiable, Codable {
    public enum CodingKeys: String, CodingKey {
        case id
        case created = "created_at"
        case inReplyToId = "in_reply_to_id"
        case inReplyToAccountId = "in_reply_to_account_id"
        case sensitive
        case spoilerText = "spoiler_text"
        case visibility
        case language
        case uri
        case url
        case repliesCount = "replies_count"
        case reblogsCount = "reblogs_count"
        case favouritesCount = "favourites_count"
        case editedAt = "edited_at"
        case content
        case reblog
        case application
        case account
        case mediaAttachments = "media_attachments"
        case mentions
        case tags
        case emojis
        case card
        case poll
        case favourited
        case reblogged
        case muted
        case bookmarked
    }

    public let id: Tagged<Status, String>
    public let created: Date
    public let inReplyToId: Status.ID?
    public let inReplyToAccountId: Account.ID?
    public let sensitive: Bool
    public let spoilerText: String
    public let visibility: Status.Visibility
    public let language: String?
    public let uri: String?
    public let url: URL?
    public let repliesCount: Int
    public let reblogsCount: Int
    public let favouritesCount: Int
    public let editedAt: Date?
    public let content: String
    public let reblog: PlaceholderCodable?
    public let application: Application?
    public let account: Account
    public let mediaAttachments: [MediaAttachment]
    public let mentions: [Mention]
    public let tags: [Tag]
    public let emojis: [Emoji]
    public let card: Card?
    public let poll: Poll?
    public let favourited: Bool?
    public let reblogged: Bool?
    public let muted: Bool?
    public let bookmarked: Bool?
}

public struct PlaceholderCodable: Codable {
}

public struct Token: Codable, Equatable {
    public enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case created = "created_at"
    }

    public let accessToken: String
    public let tokenType: String
    public let scope: String
    public let created: Date
}
