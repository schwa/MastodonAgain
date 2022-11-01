import Mastodon
import SwiftUI

struct AppSettings: View {
    @EnvironmentObject
    var appModel: AppModel

    @AppStorage("showDebuggingInfo")
    var showDebuggingInfo = false

    @AppStorage("hideSensitiveContent")
    var hideSensitiveContent = false

    @AppStorage("useMarkdownContent")
    var useMarkdownContent = false

    var body: some View {
        List {
            VStack {
                DebugDescriptionView(appModel.instance).debuggingInfo()
                Button("Log out") {
                    appModel.instance.authorization = .unauthorized
                }
                Toggle("Hide Sensitive Content", isOn: $hideSensitiveContent)
                Toggle("Show Debugging Info", isOn: $showDebuggingInfo)
                Toggle("Use Markdown Content (Very Experimental)", isOn: $useMarkdownContent)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .padding()
    }
}
