import Everything
import Mastodon
import SwiftUI

struct SigninsView: View {
    @EnvironmentObject
    var appModel: AppModel

    @State
    var selection: SignIn.ID?

    var body: some View {
        HStack() {
            VStack(spacing: 0) {
                List(appModel.signins, selection: $selection) { signin in
                    HStack(alignment: .top) {
                        signin.avatar.content
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20, alignment: .center)
                            .cornerRadius(4)
                        VStack(alignment: .leading) {
                            Text(verbatim: signin.account.displayName).bold()
                            Text(verbatim: "@\(signin.account.acct)")
                            Text(verbatim: signin.host)
                        }
                    }
                    .tag(signin.id)
                }
                .frame(width: 180)
                HStack {
                    ValueView(value: false) { isPresendingSigninSheet in
                        Button(systemImage: "plus") {
                            isPresendingSigninSheet.wrappedValue = true
                        }
                        .sheet(isPresented: isPresendingSigninSheet) {
                            SignInView() { signin in
                                if let signin {
                                    appModel.signins.append(signin)
                                }
                                isPresendingSigninSheet.wrappedValue = false
                            }
                            .padding()
                            .frame(minWidth: 640, minHeight: 480)
                        }
                    }
                    Button(systemImage: "minus") {
                        appModel.signins.removeAll(where: { $0.id == selection })
                    }
                    .disabled(selection == nil || appModel.signins.isEmpty)
                }
                .buttonStyle(.bordered)
            }
            Form {
                // TODO: TODO
                Text("TODO: Info on selected signin here.")
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: -

struct SignInView: View {
    let result: (SignIn?) -> Void

    @State
    var host: String?

    @State
    var authorization: Authorization = .unauthorized

    var body: some View {
        VStack {
            Text("Work in progress")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)

            if let host {
                NewAuthorizationFlow(host: host, authorization: $authorization)
            }
            else {
                HostPicker(host: $host)
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: host) { _ in
            update()
        }
        .onChange(of: authorization) { _ in
            update()
        }
    }

    func update() {
        if let host, case .authorized = authorization {
            Task {
                let service = Service(host: host, authorization: authorization)
                let account = try await service.myAccount()
                let (data, _) = try await URLSession.shared.data(for: URLRequest(url: account.avatar))
                let signin = SignIn(host: host, authorization: authorization, account: account, avatar: try .init(source: .data(data)))
                result(signin)
            }
        }
    }
}

struct HostPicker: View {
    let hosts = [
        "mastodon.social",
        "mastodon.online",
        "fosstodon.org",
    ]

    // TODO: PickedHost, userhost, host? Rename these!

    @State
    var pickedHost: String = "mastodon.social"

    @State
    var userHost: String = "mastodon.social"

    @Binding
    var host: String?

    var body: some View {
        Form {
            Picker("Host", selection: $pickedHost) {
                ForEach(hosts, id: \.self) { host in
                    Text(verbatim: host).tag(host)
                }
            }
            TextField("Host", text: $userHost)
            .buttonStyle(.borderedProminent)
            .disabled(userHost.isEmpty)
        }
        .toolbar {
            Button("Next...") {
                host = userHost
            }
        }
        .onChange(of: pickedHost) { pickedHost in
            userHost = pickedHost
        }
        .onSubmit {
            host = userHost
        }
    }
}

struct NewAuthorizationFlow: View {
    @EnvironmentObject
    var appModel: AppModel

    let host: String

    @Binding
    var authorization: Authorization

    @State
    var authorizationCode: String = ""

    @Environment(\.errorHandler)
    var errorHandler

    struct Mode: Equatable {
        let title: String
        let started = Date()
    }

    @State
    var mode: Mode?

    var body: some View {
        Group {
            if let mode {
                ProgressView()
                if let date = mode.started {
                    Text("\(mode.title): ") + Text(date, style: .relative).monospacedDigit()
                }
            }
            else {
                switch authorization {
                case .unauthorized:
                    PlaceholderShape().stroke()
                case .registered(let application):
                    registeredView(application)
                default:
                    Text("Already authorized!")
                }
            }
        }
        .onAppear {
            Task {
                await errorHandler {
                    try await register()
                }
            }
        }
        .onChange(of: mode, perform: { mode in
            appLogger?.log("Mode changed: \(String(describing: mode))")
        })
        .onChange(of: authorization) { authorization in
            appLogger?.log("Authorization changed: \(String(describing: authorization))")
        }
    }

    @ViewBuilder
    func registeredView(_ application: RegisteredApplication) -> some View {
        VStack {
            let url = URL(string: "https://\(host)/oauth/authorize?client_id=\(application.clientID)&scope=read+write+follow+push&redirect_uri=urn:ietf:wg:oauth:2.0:oob&response_type=code")!
            let request = URLRequest(url: url)
            WebView(request: request)
            Image(systemName: "arrow.down").font(.largeTitle)
                .foregroundColor(.red)
                .padding()
            TextField("Authorisation Code", text: $authorizationCode)
                .onSubmit {
                    Task {
                        try await getToken(with: application)
                    }
                }
                .padding()
        }
        .toolbar {
//            Button("Previous") {
//                // TODO: We dont really have a good way of getting back.
//            }
            Button("Next") {
                Task {
                    try await getToken(with: application)
                }
            }
            .disabled(authorizationCode.isEmpty)
        }
    }

    func register() async throws {
        mode = Mode(title: "Registering Application")
        let url = URL(string: "https://\(host)/api/v1/apps")!
        let request = URLRequest(url: url, formParameters: [
            "client_name": appModel.applicationName,
            "redirect_uris": "urn:ietf:wg:oauth:2.0:oob",
            "scopes": "read write follow push",
            "website": appModel.applicationWebsite,
        ])

        let (application, _) = try await URLSession.shared.json(RegisteredApplication.self, for: request)
        authorization = .registered(application)
        mode = nil
    }

    func getToken(with application: RegisteredApplication) async throws {
        mode = Mode(title: "Getting Token")
        let url = URL(string: "https://\(host)/oauth/token")!
        let request = URLRequest(url: url, formParameters: [
            "client_id": application.clientID,
            "client_secret": application.clientSecret,
            "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
            "grant_type": "authorization_code",
            "code": authorizationCode,
            "scope": "read write follow push",
        ])
        let (token, _) = try await URLSession.shared.json(Token.self, for: request)
        authorization = .authorized(application, token)
        mode = nil
    }
}
