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

    @AppStorage("currentSigninID")
    private var currentSigninID: SignIn.ID?

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
