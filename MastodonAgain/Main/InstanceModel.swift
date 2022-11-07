import Combine
import Mastodon

@MainActor
class InstanceModel: ObservableObject {
    @Published
    var signin: SignIn {
        didSet {
            service = Service(host: signin.host, authorization: signin.authorization)
        }
    }

    @Published
    var service: Service

    init(signin: SignIn) {
        self.signin = signin
        service = Service(host: signin.host, authorization: signin.authorization)
    }
}
