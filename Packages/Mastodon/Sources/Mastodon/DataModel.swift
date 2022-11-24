import Everything
import Foundation
import SwiftUI

// swiftlint:disable file_length

public struct Account: Identifiable, Codable, Sendable, Equatable {
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
    public let username: String?
    public let acct: String
    public let displayName: String
    public let locked: Bool
    public let bot: Bool
    public let discoverable: Bool?
    public let group: Bool
    public let created: Date
    public let note: HTML
    public let url: String?
    public let avatar: URL
    public let avatarStatic: URL
    public let header: String
    public let headerStatic: String
    public let followersCount: Int
    public let followingCount: Int
    public let statusesCount: Int
    public let lastStatusAt: Date?
    public let noindex: Bool?
    public let emojis: [Emoji]
    public let fields: [Field]
}

public struct Application: Codable, Sendable, Equatable {
    public let name: String
    public let website: String?
}

public struct Card: Codable, Sendable, Equatable {
    public enum CodingKeys: String, CodingKey {
        case authorName = "author_name"
        case authorURL = "author_url"
        case blurhash
        case description
        case embedURL = "embed_url"
        case height
        case html
        case image
        case providerName = "provider_name"
        case providerURL = "provider_url"
        case title
        case type
        case url
        case width
    }

    public enum CardType: String, Codable, Sendable {
        case link
        case photo
        case video
        case rich
    }

    public let authorName: String?
    public let authorURL: URL?
    public let blurhash: Blurhash?
    public let description: String?
    public let embedURL: URL?
    public let height: Double?
    public let html: String?
    public let image: URL?
    public let providerName: String?
    public let providerURL: URL?
    public let title: String?
    public let type: CardType
    public let url: URL
    public let width: Double?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName).nilify()
        authorURL = try container.decodeIfPresent(String.self, forKey: .authorURL).nilify().map { try URL(string: $0).safelyUnwrap(GeneralError.illegalValue) }
        blurhash = try container.decodeIfPresent(Blurhash.self, forKey: .blurhash)
        description = try container.decodeIfPresent(String.self, forKey: .description).nilify()
        embedURL = try container.decodeIfPresent(String.self, forKey: .embedURL).nilify().map { try URL(string: $0).safelyUnwrap(GeneralError.illegalValue) }
        height = try container.decodeIfPresent(Double.self, forKey: .height)
        html = try container.decodeIfPresent(String.self, forKey: .html).nilify()
        image = try container.decodeIfPresent(String.self, forKey: .image).nilify().map { try URL(string: $0).safelyUnwrap(GeneralError.illegalValue) }
        providerName = try container.decodeIfPresent(String.self, forKey: .providerName).nilify()
        providerURL = try container.decodeIfPresent(String.self, forKey: .providerURL).nilify().map { try URL(string: $0).safelyUnwrap(GeneralError.illegalValue) }
        title = try container.decodeIfPresent(String.self, forKey: .title).nilify()
        type = try container.decode(Card.CardType.self, forKey: .type)
        url = try container.decode(URL.self, forKey: .url)
        width = try container.decodeIfPresent(Double.self, forKey: .width)
    }
}

public struct Emoji: Codable, Sendable, Equatable {
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

public struct Field: Codable, Sendable, Equatable {
    public enum CodingKeys: String, CodingKey {
        case name
        case value
        case verifiedAt = "verified_at"
    }

    public let name: String
    public let value: HTML
    public let verifiedAt: String?
}

public struct MediaAttachment: Identifiable, Codable, Sendable, Equatable {
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

    public enum MediaType: String, Codable, Sendable, Equatable {
        case image
        case audio
        case gifv
        case video
        case unknown
    }

    public struct Meta: Codable, Sendable, Equatable {
        public struct Size: Codable, Sendable, Equatable {
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
    public let blurHash: Blurhash?
}

public struct Mention: Identifiable, Codable, Sendable, Equatable {
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

public struct Poll: Codable, Sendable, Equatable {
}

public protocol StatusProtocol: Sendable, Equatable {
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
    var content: HTML { get }
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

public struct Status: StatusProtocol, Identifiable, Codable, Sendable, Equatable {
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

    public enum Visibility: String, Codable, CaseIterable, Sendable {
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
    public let content: HTML
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

public struct ReblogStatus: StatusProtocol, Identifiable, Codable, Sendable, Equatable {
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
    public let content: HTML
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

public struct Tag: Codable, Sendable, Equatable {
    public let name: String
    public let url: URL
}

// https://docs.joinmastodon.org/methods/statuses/
public struct NewPost: Codable, Sendable, Equatable {
    public enum CodingKeys: String, CodingKey {
        case status
        case inReplyTo = "in_reply_to_id"
        case mediaIds = "media_ids"
        case sensitive
        case spoiler = "spoiler_text"
        case visibility
        case scheduled = "scheduled_at"
        case language
    }

    public var status: String
    public var inReplyTo: Status.ID?
    public var mediaIds: [MediaAttachment.ID]?
    // poll
    public var sensitive: Bool
    public var spoiler: String?
    public var visibility: Status.Visibility
    public var scheduled: Date?
    public var language: String

    public init(status: String, inReplyTo: Status.ID? = nil, mediaIds: [MediaAttachment.ID]? = nil, sensitive: Bool, spoiler: String?, visibility: Status.Visibility, scheduled: Date? = nil, language: String) {
        self.status = status
        self.inReplyTo = inReplyTo
        self.mediaIds = mediaIds
        self.sensitive = sensitive
        self.spoiler = spoiler
        self.visibility = visibility
        self.scheduled = scheduled
        self.language = language
    }
}

public extension NewPost {
    init() {
        self.init(status: "", sensitive: false, spoiler: "", visibility: .public, language: Locale.current.topLevelIdentifier)
    }
}

public struct Relationship: Codable, Identifiable, Sendable {
    public let id: Account.ID
    public let following, showingReblogs, notifying, followedBy: Bool
    public let blocking, blockedBy, muting, mutingNotifications: Bool
    public let requested, domainBlocking, endorsed: Bool
    public let note: String?

    enum CodingKeys: String, CodingKey {
        case id, following
        case showingReblogs = "showing_reblogs"
        case notifying
        case followedBy = "followed_by"
        case blocking
        case blockedBy = "blocked_by"
        case muting
        case mutingNotifications = "muting_notifications"
        case requested
        case domainBlocking = "domain_blocking"
        case endorsed
        case note
    }
}

struct Instance: Codable {
    struct Info: Codable {
        var shortDescription, fullDescription: String
        var topic: String?
        var languages: [String]
        var otherLanguagesAccepted: Bool
        var federatesWith: String
        var prohibitedContent, categories: [String]?
    }

    var id, name: String
    var addedAt: Date?
    var updatedAt, checkedAt: String
    var uptime: Int
    var up, dead: Bool
    var version: String
    var ipv6: Bool
    var httpsScore: Int
    var httpsRank: String
    var obsScore: Int
    var obsRank, users, statuses, connections: String
    var openRegistrations: Bool
    var info: Info
    var thumbnail: String
    var thumbnailProxy: String
    var activeUsers: Int
    var email, admin: String
}

public struct List: Codable {
    public typealias ID = Tagged<List, String>
    public var id: ID
    public var title: String
}

public struct SignIn: Codable, Identifiable, Sendable {
    public var id: String {
        name
    }

    public var name: String {
        "@\(account.acct)@\(host)"
    }

    public var host: String
    public var authorization: Authorization
    public var account: Account
    public var avatar: Resource<Image>

    public init(host: String, authorization: Authorization, account: Account, avatar: Resource<Image>) {
        self.host = host
        self.authorization = authorization
        self.account = account
        self.avatar = avatar
    }
}
