import Mastodon
import SwiftUI

struct AppSettings: View {
    @EnvironmentObject
    var appModel: AppModel

    @AppStorage("showDebuggingInfo")
    var showDebuggingInfo = false

    var body: some View {
        List {
            Form {



                DebugDescriptionView(appModel.authorization)


                Button("Log out") {
                    appModel.authorization = .unauthorized
                }
                Toggle("Show Debugging Info", isOn: $showDebuggingInfo)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .padding()
    }
}
