import Combine
import Foundation
import Mastodon

@MainActor
class InstanceModel: ObservableObject {
    @Published
    var signin: SignIn {
        didSet {
            // swiftlint:disable:next force_try
            service = try! Service(host: signin.host, authorization: signin.authorization)
        }
    }

    let baseURL: URL
    var token: Token? {
        signin.authorization.token
    }

    @Published
    var service: Service

    init(signin: SignIn) {
        self.signin = signin
        baseURL = URL("https://\(signin.host)")

        // swiftlint:disable:next force_try
        service = try! Service(host: signin.host, authorization: signin.authorization)
    }
}
