import Combine
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

    @Published
    var service: Service

    init(signin: SignIn) {
        self.signin = signin
        // swiftlint:disable:next force_try
        service = try! Service(host: signin.host, authorization: signin.authorization)
    }
}
