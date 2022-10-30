import Everything
import Mastodon
import SwiftUI

struct ContentView: View {
    @EnvironmentObject
    var appModel: AppModel

    var body: some View {
        Group {
            if case .authorized = appModel.authorization {
                TimelineView(timeline: Timeline(timelineType: .home))
            }
            else {
                AuthorizationFlow()
            }
        }
        .errorHostView()
    }
}
