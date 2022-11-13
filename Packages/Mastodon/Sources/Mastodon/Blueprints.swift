import Blueprint
import Foundation

// https://docs.joinmastodon.org/methods/apps/

public enum MastodonBlueprints {
    static var authorizedHeaders: [String: Parameter] {
        ["Authorization": .required("Bearer \(lookup: "userToken")")]
    }
}

public extension MastodonBlueprints {
    enum Apps {
        // TODO: create an application

        // Verify your app works.
        static let verify = Blueprint(
            path: "/api/v1/apps/verify_credentials",
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")")
            ],
            expectedResponse: JSONDecoderResponse<Application>(decoder: JSONDecoder.mastodonDecoder)
        )
    }
}

public extension MastodonBlueprints {
    enum Accounts {
        // TODO: register an account

        // Verify your app works.
        static let verify = Blueprint(
            path: "/api/v1/accounts/verify_credentials",
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")")
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // TODO: Update account credentials

        // Retrieve information
        static let retrieve = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")",
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")")
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // Statuses
        static let statuses = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/statuses",
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
                "max_id": .optional("\(lookup: "max_id")"),
                "since_id": .optional("\(lookup: "since_id")"),
                "limit": .optional("\(lookup: "limit")"),
                // TODO: documentation hints at min_id, exclude_reblogs, tagged etc.
            ],
            expectedResponse: JSONDecoderResponse<[Status]>(decoder: JSONDecoder.mastodonDecoder)
        )

        // Followers
        static let followers = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/followers",
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
                "max_id": .optional("\(lookup: "max_id")"),
                "since_id": .optional("\(lookup: "since_id")"),
                "limit": .optional("\(lookup: "limit")"),
            ],
            expectedResponse: JSONDecoderResponse<[Account]>(decoder: JSONDecoder.mastodonDecoder)
        )

        // Following
        static let following = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/following",
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
                "max_id": .optional("\(lookup: "max_id")"),
                "since_id": .optional("\(lookup: "since_id")"),
                "limit": .optional("\(lookup: "limit")"),
            ],
            expectedResponse: JSONDecoderResponse<[Account]>(decoder: JSONDecoder.mastodonDecoder)
        )

        // Featured tags
        // TODO: Define FeaturedTag
//        static let featuredTags = Blueprint(
//            path: "/api/v1/accounts/\(lookup: "id")/featured_tags",
//            headers: [
//                "Authorization": .required("Bearer \(lookup: "userToken")"),
//            ],
//            expectedResponse: JSONDecoderResponse<[FeaturedTag]>(decoder: JSONDecoder.mastodonDecoder)
//        )

        // Lists
        // TODO: Define List
//        static let lists = Blueprint(
//            path: "/api/v1/accounts/\(lookup: "id")/lists",
//            headers: [
//                "Authorization": .required("Bearer \(lookup: "userToken")"),
//            ],
//            expectedResponse: JSONDecoderResponse<[List]>(decoder: JSONDecoder.mastodonDecoder)
//        )

        // Identity proofs
        // TODO: Define IdentityProof
//        static let identityProofs = Blueprint(
//            path: "/api/v1/accounts/\(lookup: "id")/identity_proofs",
//            headers: [
//                "Authorization": .required("Bearer \(lookup: "userToken")"),
//            ],
//            expectedResponse: JSONDecoderResponse<[IdentityProof]>(decoder: JSONDecoder.mastodonDecoder)
//        )

        // Follow
        static let follow = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/follow",
            method: .post,
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
                "reblogs": .optional("\(lookup: "reblogs")"),
                "notify": .optional("\(lookup: "notify")"),
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // Unfollow
        static let unfollow = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/unfollow",
            method: .post,
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // block
        static let block = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/block",
            method: .post,
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // unblock
        static let unblock = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/unblock",
            method: .post,
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // mute
        static let mute = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/mute",
            method: .post,
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
                "notifications": .optional("\(lookup: "notifications")"),
                "duration": .optional("\(lookup: "duration")"),
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // unmute
        static let unmute = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/unmute",
            method: .post,
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // feature on profile
        static let pin = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/pin",
            method: .post,
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // unfeature on profile
        static let unpin = Blueprint(
            path: "/api/v1/accounts/\(lookup: "id")/unpin",
            method: .post,
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")"),
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )

        // user note
// TODO: we're rethinking body.
        //        static let note = Blueprint(
//            path: "/api/v1/accounts/\(lookup: "id")/note",
//            method: .post,
//            headers: [
//                "Authorization": .required("Bearer \(lookup: "userToken")"),
//            ],
////            body: try MultipartForm(content: ["name": .file(url: URL(filePath: "/tmp/test.png"))])
//            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
//        )

    }
}
