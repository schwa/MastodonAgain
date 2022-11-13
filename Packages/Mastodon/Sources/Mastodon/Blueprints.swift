import Blueprint
import Foundation

// https://docs.joinmastodon.org/methods/apps/

public enum MastodonBlueprints {
}

public extension MastodonBlueprints {
    enum Apps {
        // TODO: create an application

        // Verify your app works.
        static let verify = Blueprint(
            path: "/api/v1/apps/verify_credentials",
            method: .get,
            headers: [
                "Authorization": .required("Bearer \(lookup: "userToken")")
            ],
            expectedResponse: JSONDecoderResponse<Account>(decoder: JSONDecoder.mastodonDecoder)
        )
    }
}
