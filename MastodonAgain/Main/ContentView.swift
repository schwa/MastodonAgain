import Everything
import Mastodon
import SwiftUI

struct ContentView: View {
    @EnvironmentObject
    var appModel: AppModel

    var body: some View {
        Group {
            if let signin = appModel.currentSignin {
                MainView()
                    .environmentObject(appModel.instance(for: signin))
                    .navigationTitle("\(signin.host)")
            }
            else {
                SignInView { signin in
                    guard let signin else {
                        return
                    }
                    Task {
                        await MainActor.run {
                            appModel.signins.append(signin)
                            appModel.currentSignin = signin
                        }
                    }
                }
            }
        }
        .errorHost()
    }
}
