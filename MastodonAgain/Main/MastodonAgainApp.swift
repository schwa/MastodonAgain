import Everything
import Mastodon
import SwiftUI
import os

let appLogger: Logger? = Logger()

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
        .keyboardShortcut(.init("1"))
        #endif
        #if os(macOS)
            WindowGroup("New Post", for: NewPostWindow.self) { open in
                NewPostView(open: open)
                    .environmentObject(appModel)
                    .environmentObject(InstanceModel(signin: appModel.currentSignin!))
            }
            .keyboardShortcut(.init("N"))
            Settings {
                AppSettings()
                    .environmentObject(appModel)
            }
        #endif
    }
}

