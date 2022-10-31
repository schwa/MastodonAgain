import Mastodon
import SwiftUI

struct AppSettings: View {
    @EnvironmentObject
    var appModel: AppModel

    @AppStorage("showDebuggingInfo")
    var showDebuggingInfo = false

    var body: some View {
        List {
            VStack {
                DebugDescriptionView(appModel.instance).debuggingInfo()
                Button("Log out") {
                    appModel.instance.authorization = .unauthorized
                }
                Toggle("Show Debugging Info", isOn: $showDebuggingInfo)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .padding()
    }
}
