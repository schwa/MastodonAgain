import SwiftUI
import Mastodon
import Everything
import WebKit

struct AuthorizationFlow: View {

    @EnvironmentObject
    var appModel: AppModel

    @State
    var authorizationCode: String = ""

    @State
    var clientName = "MastodonAgain"

    @State
    var website = "https://schwa.io/MastodonAgain"

    var body: some View {
        switch appModel.authorization {
        case .unauthorized:
            GroupBox("Login") {
                TextField("Host", text: $appModel.host)
                GroupBox("Application") {
                    Group {
                        TextField("Application Name", text: $clientName)
                        TextField("Website", text: $website)
                    }
                    Button("Register Application") {
                        Task {
                            try await register()
                        }
                    }
                }
            }
            .frame(maxWidth: 320)
        case .registered(let application):
            let url = URL(string: "https://\(appModel.host)/oauth/authorize?client_id=\(application.clientID)&scope=read+write+follow+push&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code")!
            let request = URLRequest(url: url)
            ViewAdaptor {
                let webConfiguration = WKWebViewConfiguration()
                let view = WKWebView(frame: .zero, configuration: webConfiguration)
                view.load(request)
                return view
            } update: { view in
            }
            Image(systemName: "arrow.down").font(.largeTitle).foregroundColor(.red)
            .padding()
            TextField("Authorisation Code", text: $authorizationCode)
                .onSubmit {
                    Task {
                        try await getToken(with: application)
                    }
                }
            .padding()
        default:
            Text("Already authorized!")
        }
    }

    func register() async throws {
        let url = URL(string: "https://\(appModel.host)/api/v1/apps")!
        let request = URLRequest(url: url, formParameters: [
            "client_name": clientName,
            "redirect_uris": "urn:ietf:wg:oauth:2.0:oob",
            "scopes": "read write follow push",
            "website": website
        ])

        let (application, _) = try await URLSession.shared.json(RegisteredApplication.self, for: request)
        self.appModel.authorization = .registered(application)
    }

    func getToken(with application: RegisteredApplication) async throws {
        let url = URL(string: "https://\(appModel.host)/oauth/token")!
        let request = URLRequest(url: url, formParameters: [
            "client_id": application.clientID,
            "client_secret": application.clientSecret,
            "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "scope": "read write follow push",

        ])
        let (token, _) = try await URLSession.shared.json(Token.self, for: request)
        self.appModel.authorization = .authorized(application, token)
    }

}

