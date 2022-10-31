import SwiftUI
import Mastodon
import Everything

struct MainView: View {
    @EnvironmentObject
    var appModel: AppModel

    @SceneStorage("MainView.selection")
    var selection = MainTabs.home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Home", systemImage: "house").tag(MainTabs.home)
                Label("Public", systemImage: "person.3").tag(MainTabs.public)
                Label("Federated", systemImage: "person.3").tag(MainTabs.federated)
                Label("Local", systemImage: "person.3").tag(MainTabs.local)
                Label("Direct Messages", systemImage: "bubble.left").tag(MainTabs.directMessages)
                Label("Search", systemImage: "magnifyingglass").tag(MainTabs.search)
                Label("Me", systemImage: "person.text.rectangle").badge(1).tag(MainTabs.me)
                Label("Canned Timeline", systemImage: "oilcan").tag(MainTabs.cannedTimeline)
            }
        } detail: {
            switch selection {
            case .home:
                TimelineView(timeline: Timeline(host: appModel.host, timelineType: .home, title: "Home"))
            case .federated:
                TimelineView(timeline: Timeline(host: appModel.host, timelineType: .federated, title: "Federated"))
            case .local:
                TimelineView(timeline: Timeline(host: appModel.host, timelineType: .local, title: "Local"))
            case .public:
                TimelineView(timeline: Timeline(host: appModel.host, timelineType: .public, title: "Public"))
            case .directMessages:
                WorkInProgressView().opacity(0.2)
            case .search:
                WorkInProgressView().opacity(0.2)
            case .me:
                WorkInProgressView().opacity(0.2)
            case .cannedTimeline:
                let url = Bundle.main.url(forResource: "canned_timeline", withExtension: "json")!
                let data = try! Data(contentsOf: url)
                // Do not use mastodon decoder for canned timeline
                let timeline = try! JSONDecoder().decode(Timeline.self, from: data)
                TimelineView(timeline: timeline, allowRefresh: false)
            }
        }
    }
}

enum MainTabs: String {
    case home
    case `public`
    case federated
    case local
    case directMessages
    case search
    case me
    case cannedTimeline
}
