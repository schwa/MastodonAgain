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
    var statusRowMode = StatusRow.Mode.alt

    @Stored("Signins")
    var signins: [SignIn] = []

    @AppStorage("currentSigninID")
    private var currentSigninID: SignIn.ID?

    @AppStorage("relativeDateFormattingStyle")
    private var _relativeDateFormattingStyle: RelativeDateTimeFormatter.UnitsStyle =  .short
    private lazy var _relativeDateFormatter = updateRelativeDateFormatter()
    private func updateRelativeDateFormatter() -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = _relativeDateFormattingStyle
        return formatter
    }

    /// Units style to use for relative dates.
    /// Bind this property to UI.
    var relativeDateFormattingStyle: RelativeDateTimeFormatter.UnitsStyle {
        get { _relativeDateFormattingStyle }
        set {
            _relativeDateFormattingStyle = newValue
            _relativeDateFormatter = updateRelativeDateFormatter()
        }
    }

    func relativeDate(_ date: Date) -> String {
        return _relativeDateFormatter.localizedString(for: date, relativeTo: .now)
    }

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
}
