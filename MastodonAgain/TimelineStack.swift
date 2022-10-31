import SwiftUI
import Mastodon

struct TimelineStack: View {
    let timeline: Timeline

    enum Page {
        case timeline(Timeline)
    }

    @State
    var path: [Page]

    init(timeline: Timeline) {
        self.timeline = timeline
        self._path = State(initialValue: [.timeline(timeline)])
    }

    var body: some View {
        //NavigationStack {
            TimelineView(timeline: timeline)
        //}
    }
}
