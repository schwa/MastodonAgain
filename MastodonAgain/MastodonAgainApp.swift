import Everything
import Mastodon
import SwiftUI

@main
struct MastodonAgainApp: App {
    @StateObject
    var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
        }
        #if os(macOS)
            Settings {
                AppSettings()
                    .environmentObject(appModel)
            }
        #endif
    }
}
