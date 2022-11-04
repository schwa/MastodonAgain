import Mastodon
import SwiftUI

struct AppSettings: View {
    @EnvironmentObject
    var appModel: AppModel

    var body: some View {
        List {
            VStack {
                DebugDescriptionView(appModel.instance).debuggingInfo()
                Button("Log out") {
                    appModel.instance.authorization = .unauthorized
                }
                Toggle("Hide Sensitive Content", isOn: $appModel.hideSensitiveContent)
                Toggle("Show Debugging Info", isOn: $appModel.showDebuggingInfo)
                Toggle("Use Markdown Content (Very Experimental)", isOn: $appModel.useMarkdownContent)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .padding()
    }
}
