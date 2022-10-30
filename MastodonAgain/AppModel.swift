import Mastodon
import SwiftUI

class AppModel: ObservableObject {
    @Published
    var host = "mastodon.social"

    @Published
    var authorization = Authorization.unauthorized {
        didSet {
            Storage.shared["authorization"] = authorization
            Task {
                if case .authorized(_, let token) = authorization {
                    await service.update(host: host, token: token)
                }
                else {
                    await service.update(host: nil, token: nil)
                }
            }
        }
    }

    let service = Service()

    init() {
        authorization = Storage.shared["authorization"] ?? .unauthorized
    }
}

enum Authorization: Codable {
    case unauthorized
    case registered(RegisteredApplication)
    case authorized(RegisteredApplication, Token)
}
