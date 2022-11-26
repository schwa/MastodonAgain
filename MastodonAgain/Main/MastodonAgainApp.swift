import Everything
import Mastodon
import os
import SwiftUI

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
                NewPostHost(open: open)
                    .environmentObject(appModel)
                    // ISSUE: https://github.com/schwa/MastodonAgain/issues/79
                    .environmentObject(appModel.instance(for: appModel.currentSignin!))
                    .errorHost()
            }
            .keyboardShortcut("N", modifiers: .command)
            Settings {
                AppSettings()
                    .environmentObject(appModel)
            }
        #endif
    }
}
