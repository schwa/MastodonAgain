import Mastodon
import SwiftUI

class AppModel: ObservableObject {
    @Published
    var instance = Instance("mastodon.social")

    @Published
    var authorization = Authorization.unauthorized {
        didSet {
            Storage.shared["authorization"] = authorization
            Task {
                if case .authorized(_, let token) = authorization {
                    await service.update(instance: instance, token: token)
                }
                else {
                    await service.update(instance: nil, token: nil)
                }
            }
        }
    }

    @Published
    var showDebugInfo = true

    let service = Service()

    init() {
        authorization = Storage.shared["authorization"] ?? .unauthorized
    }
}

enum Authorization: Codable, Equatable {
    case unauthorized
    case registered(RegisteredApplication)
    case authorized(RegisteredApplication, Token)
}
