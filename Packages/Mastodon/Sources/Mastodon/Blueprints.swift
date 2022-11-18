import Blueprint
import Everything
import Foundation

// swiftlint:disable file_length
// swiftlint:disable type_body_length

func standardResponse<T>(_ type: T.Type) -> some Response where T: Decodable {
    IfStatus(200) { data, _ in
        try JSONDecoder.mastodonDecoder.decode(T.self, from: data)
    }
}

public struct Form {
    let parameters: [FormParameter]

    init(@FormBuilder _ parameters: () -> [FormParameter]) {
        self.parameters = parameters()
    }
}

extension Form: Request {
    public func apply(request: inout PartialRequest) throws {
        let bodyString = parameters.map { parameter in
            let key = parameter.name
                .replacing(" ", with: "+")
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics + .punctuationCharacters + "+")!
            let value = parameter.value ?? ""
                .replacing(" ", with: "+")
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics + .punctuationCharacters + "+")!
            return "\(key)=\(value)"
        }
        .joined(separator: "&")
        request.headers.append(.init(name: "Content-Type", value: "application/x-www-form-urlencoded; charset=utf-8"))
        request.body = bodyString.data(using: .utf8)!
    }
}

@resultBuilder
enum FormBuilder {
    static func buildBlock(_ components: FormParameter?...) -> [FormParameter] {
        components.compactMap { $0 }
    }
}

public struct FormParameter {
    let name: String
    let value: String?
}

extension Array: Request where Element: Request {
    public func apply(request: inout PartialRequest) throws {
        try forEach { element in
            try element.apply(request: &request)
        }
    }
}

extension FormParameter: Request {
    public func apply(request: inout PartialRequest) throws {
        unimplemented()
    }
}

// MARK: -

public enum MastodonAPI {
}

// MARK: -

// https://docs.joinmastodon.org/methods/apps/

public extension MastodonAPI {
    enum Apps {
        public struct Create: Request, Response {
            let baseURL: URL
            let token: Token
            let clientName: String
            let redirectURIs: String
            let scopes: String?
            let website: String?

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/apps")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                Form {
                    FormParameter(name: "client_name", value: clientName)
                    FormParameter(name: "redirect_uris", value: clientName)
                    scopes.map { FormParameter(name: "scopes", value: $0) }
                    website.map { FormParameter(name: "website", value: $0) }
                }
            }

            public var response: some Response {
                standardResponse(Application.self)
            }
        }

        public struct Verify: Request, Response {
            let baseURL: URL
            let token: Token

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/apps/verify_credentials")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Application.self)
            }
        }
    }
}

// MARK: -

// https://docs.joinmastodon.org/methods/accounts/

public extension MastodonAPI {
    enum Accounts {
        public struct Register: Request, Response {
            let baseURL: URL
            let token: Token
            let username: String
            let email: String
            let password: String
            let agreement: Bool
            let locale: String
            let reason: String?

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                Form {
                    FormParameter(name: "username", value: username)
                    FormParameter(name: "email", value: email)
                    FormParameter(name: "password", value: password)
                    FormParameter(name: "agreement", value: agreement ? "true" : "false")
                    FormParameter(name: "locale", value: locale)
                    reason.map { FormParameter(name: "reason", value: $0) }
                }
            }

            public var response: some Response {
                standardResponse(Application.self)
            }
        }

        public struct Verify: Request, Response {
            let baseURL: URL
            let token: Token

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/accounts/verify_credentials")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Account.self)
            }
        }

        public struct Update: Request, Response {
            let baseURL: URL
            let token: Token
            let discoverable: String?
            let bot: Bool?
            let displayName: String?
            let note: String?
            let avatar: String? // TODO: Avatar image encoded using multipart/form-data
            let header: String? // TODO: Avatar image encoded using multipart/form-data
            let locked: Bool?
            let sourcePrivacy: String?
            let sourceSensitive: Bool?
            let sourceLanguage: String?
            let fields: [String: String]?

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/update_credentials")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                Form {
                }
                unimplemented() // TODO: TODO
            }

            public var response: some Response {
                standardResponse(Application.self)
            }
        }

        public struct Retrieve: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Account.self)
            }
        }

        // Statuses

        public struct Statuses: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID
            let maxID: Account.ID?
            let sinceID: Account.ID?
            let limit: Int?
            let minID: Account.ID?
            let excludeReblogs: Bool?
            let tagged: Bool? // TODO: ?

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/statuses")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                maxID.map { URLQueryItem(name: "max_id", value: $0.rawValue) }
                sinceID.map { URLQueryItem(name: "since_id", value: $0.rawValue) }
                limit.map { URLQueryItem(name: "limit", value: String($0)) }
                minID.map { URLQueryItem(name: "min_id", value: $0.rawValue) }
                excludeReblogs.map { URLQueryItem(name: "exclude_reblogs", value: String($0)) }
                tagged.map { URLQueryItem(name: "tagged", value: String($0)) }
            }

            public var response: some Response {
                standardResponse([Status].self)
            }
        }

        public struct Followers: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID
            let maxID: Account.ID?
            let sinceID: Account.ID?
            let limit: Int?

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/followers")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                maxID.map { URLQueryItem(name: "max_id", value: $0.rawValue) }
                sinceID.map { URLQueryItem(name: "since_id", value: $0.rawValue) }
                limit.map { URLQueryItem(name: "limit", value: String($0)) }
            }

            public var response: some Response {
                standardResponse([Account].self)
            }
        }

        public struct Following: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID
            let maxID: Account.ID?
            let sinceID: Account.ID?
            let limit: Int?

            public init(baseURL: URL, token: Token, id: Account.ID, maxID: Account.ID? = nil, sinceID: Account.ID? = nil, limit: Int? = nil) {
                self.baseURL = baseURL
                self.token = token
                self.id = id
                self.maxID = maxID
                self.sinceID = sinceID
                self.limit = limit
            }

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/following")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                maxID.map { URLQueryItem(name: "max_id", value: $0.rawValue) }
                sinceID.map { URLQueryItem(name: "since_id", value: $0.rawValue) }
                limit.map { URLQueryItem(name: "limit", value: String($0)) }
            }

            public var response: some Response {
                standardResponse([Account].self)
            }
        }

        public struct FeaturedTags: Request, Response {
            // TODO: Move
            public struct FeaturedTag: Codable {
                let id: String // TODO: Make tagged.
                let name: String
                let statuses_count: Int
                let last_status_at: Date
            }

            let baseURL: URL
            let token: Token
            let id: Account.ID

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/featured_tags")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse([FeaturedTag].self)
            }
        }

        public struct Lists: Request, Response {
            // TODO: Move

            let baseURL: URL
            let token: Token
            let id: Account.ID

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/lists")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse([Mastodon.List].self)
            }
        }

        public struct IdentityProofs: Request, Response {
            // TODO: Move
            public struct IdentityProof: Codable {
                let provider: String
                let provider_username: String
                let updated_at: Date
                let proof_url: URL
                let profile_url: URL
            }

            let baseURL: URL
            let token: Token
            let id: Account.ID

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/identity_proofs")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse([IdentityProof].self)
            }
        }

        public struct Follow: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID
            let reblogs: Bool?
            let notify: Bool?

            public init(baseURL: URL, token: Token, id: Account.ID, reblogs: Bool? = nil, notify: Bool? = nil) {
                self.baseURL = baseURL
                self.token = token
                self.id = id
                self.reblogs = reblogs
                self.notify = notify
            }

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/follow")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                reblogs.map { URLQueryItem(name: "reblogs", value: String($0)) }
                notify.map { URLQueryItem(name: "notify", value: String($0)) }
            }

            public var response: some Response {
                standardResponse(Relationship.self)
            }
        }

        public struct Unfollow: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID

            public init(baseURL: URL, token: Token, id: Account.ID) {
                self.baseURL = baseURL
                self.token = token
                self.id = id
            }

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/unfollow")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Relationship.self)
            }
        }

        public struct Block: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/block")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Relationship.self)
            }
        }

        public struct Unblock: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/unblock")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Relationship.self)
            }
        }

        public struct Mute: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID
            let notifications: Bool?
            let duration: Int?

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/mute")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                notifications.map { URLQueryItem(name: "notifications", value: String($0)) }
                duration.map { URLQueryItem(name: "duration", value: String($0)) }
            }

            public var response: some Response {
                standardResponse(Relationship.self)
            }
        }

        public struct Unmute: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/unmute")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Relationship.self)
            }
        }

        public struct Pin: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/pin")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Relationship.self)
            }
        }

        public struct Unpin: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/unpin")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Relationship.self)
            }
        }

        public struct Note: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Account.ID
            let comment: String?

            public init(baseURL: URL, token: Token, id: Account.ID, comment: String? = nil) {
                self.baseURL = baseURL
                self.token = token
                self.id = id
                self.comment = comment
            }

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/\(id.rawValue)/note")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                Form {
                    comment.map { FormParameter(name: "comment", value: $0) }
                }
            }

            public var response: some Response {
                standardResponse(Relationship.self)
            }
        }

        public struct Relationships: Request, Response {
            let baseURL: URL
            let token: Token
            let ids: [Account.ID]
            //        ////        // TODO: Docs say to use a query like this - `id[]=1&id[]=2` - which is BIZARRE

            public init(baseURL: URL, token: Token, ids: [Account.ID]) {
                self.baseURL = baseURL
                self.token = token
                self.ids = ids
            }

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/accounts/relationships")
                ids.map { URLQueryItem(name: "id[]", value: $0.rawValue) }
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse([Relationship].self)
            }
        }

        public struct Search: Request, Response {
            let baseURL: URL
            let token: Token
            let query: String
            let limit: Int?
            let resolve: Bool?
            let following: Bool?

            public init(baseURL: URL, token: Token, query: String, limit: Int? = nil, resolve: Bool? = nil, following: Bool? = nil) {
                self.baseURL = baseURL
                self.token = token
                self.query = query
                self.limit = limit
                self.resolve = resolve
                self.following = following
            }

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/accounts/search")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
                URLQueryItem(name: "q", value: query)
                limit.map { URLQueryItem(name: "limit", value: String($0)) }
                resolve.map { URLQueryItem(name: "resolve", value: String($0)) }
                following.map { URLQueryItem(name: "limit", value: String($0)) }
            }

            public var response: some Response {
                standardResponse([Account].self)
            }
        }
    }
}

// MARK: -

// https://docs.joinmastodon.org/methods/statuses/

public extension MastodonAPI {
    enum Statuses {
        //        struct Publish: Request, Response {
        //            let baseURL: URL
        //            let token: Token
        //
        //            var request: some Request {
        //                Method.post
        //                baseURL
        //                URLPath("/api/v1/statuses")
        //                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
        //            }
        //
        //            var response: some Response {
        //                standardResponse(Status.self)
        //            }
        //        }

        public struct View: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Delete: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.delete
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Context: Request, Response {
            public struct Context_: Codable {
                let ancestors: [Status]
                let descendants: [Status]
            }

            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/context")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Context_.self)
            }
        }

        public struct RebloggedBy: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/reblogged_by")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse([Account].self)
            }
        }

        public struct FavouritedBy: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/favourited_by")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse([Account].self)
            }
        }

        public struct Favourite: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/favourite")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Unfavourite: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/unfavourite")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Reblog: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/reblog")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Unreblog: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/unreblog")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Bookmark: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/bookmark")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Unbookmark: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/unbookmark")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Mute: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/mute")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Unmute: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/unmute")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Pin: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/pin")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Unpin: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Status.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/statuses/\(id.rawValue)/pin")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }
    }
}

// https://docs.joinmastodon.org/methods/timelines/

public extension MastodonAPI {
    enum Timelimes {
        public struct Public: Request, Response {
            let baseURL: URL
            let token: Token
            let local: Bool?
            let remote: Bool?
            let onlyMedia: Bool?
            let maxID: Status.ID?
            let sinceID: Status.ID?
            let minID: Status.ID?
            let limit: Int?

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/timelines/public")
                local.map { URLQueryItem(name: "local", value: String($0)) }
                remote.map { URLQueryItem(name: "remote", value: String($0)) }
                onlyMedia.map { URLQueryItem(name: "only_media", value: String($0)) }
                maxID.map { URLQueryItem(name: "max_id", value: $0.rawValue) }
                sinceID.map { URLQueryItem(name: "since_id", value: $0.rawValue) }
                minID.map { URLQueryItem(name: "min_id", value: $0.rawValue) }
                limit.map { URLQueryItem(name: "limit", value: String($0)) }
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Hashtag: Request, Response {
            let baseURL: URL
            let token: Token
            let hashtag: String
            let local: Bool?
            let onlyMedia: Bool?
            let maxID: Status.ID?
            let sinceID: Status.ID?
            let minID: Status.ID?
            let limit: Int?

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/timelines/tag/\(hashtag)")
                local.map { URLQueryItem(name: "local", value: String($0)) }
                onlyMedia.map { URLQueryItem(name: "only_media", value: String($0)) }
                maxID.map { URLQueryItem(name: "max_id", value: $0.rawValue) }
                sinceID.map { URLQueryItem(name: "since_id", value: $0.rawValue) }
                minID.map { URLQueryItem(name: "min_id", value: $0.rawValue) }
                limit.map { URLQueryItem(name: "limit", value: String($0)) }
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct Home: Request, Response {
            let baseURL: URL
            let token: Token
            let local: Bool?
            let maxID: Status.ID?
            let sinceID: Status.ID?
            let minID: Status.ID?
            let limit: Int?

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/timelines/home")
                local.map { URLQueryItem(name: "local", value: String($0)) }
                maxID.map { URLQueryItem(name: "max_id", value: $0.rawValue) }
                sinceID.map { URLQueryItem(name: "since_id", value: $0.rawValue) }
                minID.map { URLQueryItem(name: "min_id", value: $0.rawValue) }
                limit.map { URLQueryItem(name: "limit", value: String($0)) }
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }

        public struct List: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Mastodon.List.ID
            let maxID: Status.ID?
            let sinceID: Status.ID?
            let minID: Status.ID?
            let limit: Int?

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/timelines/list/\(id.rawValue)")
                maxID.map { URLQueryItem(name: "max_id", value: $0.rawValue) }
                sinceID.map { URLQueryItem(name: "since_id", value: $0.rawValue) }
                minID.map { URLQueryItem(name: "min_id", value: $0.rawValue) }
                limit.map { URLQueryItem(name: "limit", value: String($0)) }
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Status.self)
            }
        }
    }
}

// https://docs.joinmastodon.org/methods/notifications/

public extension MastodonAPI {
    enum Notifications {
        public struct GetAll: Request, Response {
            let baseURL: URL
            let token: Token
            let maxID: Status.ID?
            let sinceID: Status.ID?
            let minID: Status.ID?
            let limit: Int?
            let excludeTypes: [NotificationType]?
            let from: Account.ID?

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/notifications")
                maxID.map { URLQueryItem(name: "max_id", value: $0.rawValue) }
                sinceID.map { URLQueryItem(name: "since_id", value: $0.rawValue) }
                minID.map { URLQueryItem(name: "min_id", value: $0.rawValue) }
                limit.map { URLQueryItem(name: "limit", value: String($0)) }
                excludeTypes.map { URLQueryItem(name: "limit", value: "[" + $0.map { $0.rawValue }.joined(separator: ",") + "]") }
                from.map { URLQueryItem(name: "account_id", value: $0.rawValue) }
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse([Notification].self)
            }
        }

        public struct Single: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Notification.ID

            public var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/notifications/\(id.rawValue)")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Notification.self)
            }
        }

        public struct Clear: Request, Response {
            let baseURL: URL
            let token: Token

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/notifications/clear")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Notification.self) // TODO: Empty
            }
        }

        public struct Dismiss: Request, Response {
            let baseURL: URL
            let token: Token
            let id: Notification.ID

            public var request: some Request {
                Method.post
                baseURL
                URLPath("/api/v1/notifications/\(id.rawValue)/dismiss")
                Header(name: "Authorization", value: "Bearer \(token.accessToken)")
            }

            public var response: some Response {
                standardResponse(Notification.self) // TODO: Empty
            }
        }
    }
}

public enum NotificationType: String, Codable {
    case follow
    case favourite
    case reblog
    case mention
    case poll
    case followRequest = "follow_request"
}

public struct Notification: Identifiable, Codable {
    public typealias ID = Tagged<Notification, String>

    public var id: ID

    // TODO:
}
