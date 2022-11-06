import Combine
import Mastodon

@MainActor
class InstanceModel: ObservableObject {
    @Published
    var signin: SignIn {
        didSet {
            self.service = Service(host: signin.host, authorization: signin.authorization)
        }
    }

    @Published
    var service: Service

    init(signin: SignIn) {
        self.signin = signin
        self.service = Service(host: signin.host, authorization: signin.authorization)
    }
}
