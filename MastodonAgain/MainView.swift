import SwiftUI
import Mastodon

struct MainView: View {
    @EnvironmentObject
    var appModel: AppModel

    @State
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
            }
        } detail: {
            switch selection {
            case .home:
                TimelineView(timeline: Timeline(host: appModel.host, timelineType: .home))
            case .federated:
                TimelineView(timeline: Timeline(host: appModel.host, timelineType: .federated))
            case .local:
                TimelineView(timeline: Timeline(host: appModel.host, timelineType: .local))
            case .public:
                TimelineView(timeline: Timeline(host: appModel.host, timelineType: .public))
            case .directMessages:
                WorkInProgressView().opacity(0.2)
            case .search:
                WorkInProgressView().opacity(0.2)
            case .me:
                WorkInProgressView().opacity(0.2)
            }
        }
    }
}

enum MainTabs {
    case home
    case `public`
    case federated
    case local
    case directMessages
    case search
    case me
}
