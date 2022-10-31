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
        .keyboardShortcut(.init("N", modifiers: .shift))
        #if os(macOS)
            WindowGroup("New Post", for: NewPost.self) { newPost in
                NewPostView(newPost: newPost)
                    .environmentObject(appModel)
            }
            .keyboardShortcut(.init("N"))
            Settings {
                AppSettings()
                    .environmentObject(appModel)
            }
        #endif
    }
}

