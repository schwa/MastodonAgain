import SwiftUI
import Mastodon
import Everything

@main
struct MastodonAgainApp: App {

    @StateObject
    var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
            .environmentObject(appModel)
        }
        Settings {
            AppSettings()
            .environmentObject(appModel)
        }
    }
}

