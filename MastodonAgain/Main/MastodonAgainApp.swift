import Everything
import Mastodon
import os
import SwiftUI

let appLogger: Logger? = Logger()

@main
struct MastodonAgainApp: App {
    @StateObject
    var appModel = AppModel()

    @Environment(\.openWindow)
    var openWindow

    var body: some Scene {
        WindowGroup("Main") {
            ContentView()
                .environmentObject(appModel)
        }

//        .commands {
//            CommandGroup(after: .newItem) {
//                Button("New Post") {
//                    openWindow(value: NewPostWindow.)
//                }
//            }
//        }

        #if os(macOS)
        .keyboardShortcut(.init("1"), modifiers: .command)
        #endif
        #if os(macOS)
            WindowGroup("Post", for: NewPostWindow.self) { open in
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
