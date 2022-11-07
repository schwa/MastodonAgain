import Mastodon
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
    var statusRowMode = TimelineView.Mode.large

    @Stored("Signins")
    var signins: [SignIn] = []

//    @available(*, deprecated, message: "currentSigninID is deprecated")
    @AppStorage("currentSigninID")
    var currentSigninID: SignIn.ID?

    @available(*, deprecated, message: "currentSignin is deprecated")
    var currentSignin: SignIn? {
        get {
            guard let currentSigninID else {
                return nil
            }
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
}

// TODO: Hack
extension UUID: RawRepresentable {
    public init?(rawValue: String) {
        self = UUID(uuidString: rawValue)!
    }

    public var rawValue: String {
        uuidString
    }
}
