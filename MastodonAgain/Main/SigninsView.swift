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
    @EnvironmentObject
    var appModel: AppModel
    
    @Environment(\.errorHandler)
    var errorHandler

    @StateObject
    var signInModel = SignInViewModel()
        
    let result: (SignIn?) -> Void

    var body: some View {
        VStack {
            Text("Work in progress")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
            
            if let _ = signInModel.host {
                Text( "Registering app....." )
            }
            else {
                HostPicker(host: $signInModel.host)
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: signInModel.host) { _ in
            Task {
                await errorHandler {
                    switch await signInModel.authorization {
                        case .unauthorized:
                            // Register application
                            try await signInModel.register(applicationName: appModel.applicationName, applicationWebsite: appModel.applicationWebsite)

                        default:
                            // handled below
                            break
                    }
                    
                }
            }
        }
        .onChange(of: signInModel.authorization) { _ in
            Task {
                await errorHandler {
                    switch await signInModel.authorization {
                        case .registered(let application):
                            let authCode = try await signInModel.signIn(clientID: application.clientID)
                            
                            try await signInModel.exchangeCodeForToken(application: application, authorisationCode: authCode)

                        case .authorized:
                            let signin = try await signInModel.getAccountDetails()
                            result(signin)

                        default:
                            // Do nothing - handled above
                            break
                    }
                }
            }
        }
    }
    
    func registerApplication() async throws {
        try await signInModel.register(applicationName: appModel.applicationName, applicationWebsite: appModel.applicationWebsite)
    }
    
    func authoriseApp( application : RegisteredApplication ) async throws {
        let authCode = try await signInModel.signIn(clientID: application.clientID)
        
        try await signInModel.exchangeCodeForToken(application: application, authorisationCode: authCode)
    }
    
    func getAccountDetails() async throws {
        let signin = try await signInModel.getAccountDetails()
        result(signin)
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
