import Everything
import Mastodon
import Storage
import SwiftUI

@MainActor
class AppModel: ObservableObject {
    @AppStorage("applicationName")
    var applicationName = Bundle.main.displayName!

    @AppStorage("applicationWebsite")
    var applicationWebsite = "http://schwa.io/mastodon-again"

    @AppStorage("showDebuggingInfo")
    var showDebuggingInfo = false

    @AppStorage("hideSensitiveContent")
    var hideSensitiveContent = false

    @AppStorage("useMarkdownContent")
    var useMarkdownContent = false

    @AppStorage("statusRowMode")
    var statusRowMode = StatusRow.Mode.large

    @Published
    var signins: [SignIn] = [] {
        didSet {
            // TODO: Hardcoded key
            Task {
                try await storage.set(key: "signins", value: signins)
            }
        }
    }

    let storage: Storage

    @AppStorage("currentSigninID")
    private var currentSigninID: SignIn.ID?

    var currentSignin: SignIn? {
        get {
            guard let currentSigninID else {
                return nil
            }
            let s = "SIGNIN: \(currentSigninID), \(signins.map(\.id))"
            appLogger?.log("\(s)")
            return signins.first(identifiedBy: currentSigninID)
        }
        set {
            guard let newValue else {
                currentSigninID = nil
                return
            }
            assert(signins.contains(where: { $0.id == newValue.id }))
            currentSigninID = newValue.id
        }
    }

    private
    var instances: [String: InstanceModel] = [:]

    func instance(for signIn: SignIn) -> InstanceModel {
        if let instance = instances[signIn.name] {
            return instance
        }
        else {
            let instance = InstanceModel(signin: signIn)
            instances[signIn.name] = instance
            return instance
        }
    }

    init() {
        do {
            let version = 3 // TODO: Move into constants
            let filename = "AppData.v\(version)-storage.data"
            let path = try FSPath.specialDirectory(.applicationSupportDirectory) / filename
            storage = try Storage(path: path.path) { registration in
                registration.registerJSON(type: [SignIn].self)
            }        // TODO: this can contain sensitive info ("tokens")
            Task {
                // TODO: Force try
                // swiftlint:disable:next force_try
                self.signins = try! await storage.get(key: "signins") ?? []
            }
        }
        catch {
            fatal(error: error)
        }
    }
}
