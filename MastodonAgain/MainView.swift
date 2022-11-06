import SwiftUI
import Mastodon
import Everything

struct MainView: View {
    @EnvironmentObject
    var appModel: AppModel

//    @SceneStorage("MainView.selection")
    @State
    var selection: MainTabs? = MainTabs.home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(MainTabs.allCases, id: \.self) { tab in
                    Label {
                        Text(tab.title)
                    } icon: {
                        tab.image
                    }
                    .tag(tab)
                }
            }
        } detail: {
            if let timelineType = selection!.timelineType {
                if timelineType == .canned {
                    unimplemented()
//                    let url = Bundle.main.url(forResource: "canned_timeline", withExtension: "json")!
//                    let data = try! Data(contentsOf: url)
//                    // Do not use mastodon decoder for canned timeline
//                    let loadedTimeline = try! JSONDecoder().decode(Timeline.self, from: data)
//                    let timeline = Timeline(instance: appModel.instance, timelineType: timelineType)
//                    TimelineStack(timeline: timeline)
                }
                else {
                    let timeline = Timeline(instance: appModel.instance, timelineType: timelineType)
                    TimelineStack(timeline: timeline)
                }
            }
            else {
                WorkInProgressView().opacity(0.2)
            }
        }
        .toolbar {
            Toggle("Debug", isOn: $appModel.showDebuggingInfo)
                .toggleStyle(ImageToggleStyle())
        }
    }
}

struct ImageToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() }
        label: {
            if configuration.isOn {
                Image(systemName: "ladybug").foregroundColor(.red).symbolVariant(.circle)
            }
            else {
                Image(systemName: "ladybug")
            }
        }
    }
}

enum MainTabs: String, CaseIterable {
    case home
    case `public`
    case federated
    case local
//    case directMessages
//    case search
//    case me
//    case cannedTimeline

    var timelineType: TimelineType? {
        switch self {
        case .home:
            return .home
        case .public:
            return .public
        case .federated:
            return .federated
        case .local:
            return .local
//        case .cannedTimeline:
//            return .canned
        default:
            return nil
        }
    }

    var title: String {
        switch (self, timelineType) {
        case (_, .some(let timeline)):
            return timeline.title
//        case (.directMessages, nil):
//            return "Direct Messages"
//        case (.search, nil):
//            return "Search"
//        case (.me, nil):
//            return "Me"
        default:
            fatalError("Fallthrough")
        }
    }

    var image: Image {
        switch (self, timelineType) {
        case (_, .some(let timeline)):
            return timeline.image
        default:
            return Image(systemName: "gear")
        }
    }

//        Label("Home", systemImage: "house").tag(MainTabs.home)
//        Label("Public", systemImage: "person.3").tag(MainTabs.public)
//        Label("Federated", systemImage: "person.3").tag(MainTabs.federated)
//        Label("Local", systemImage: "person.3").tag(MainTabs.local)
//        Label("Direct Messages", systemImage: "bubble.left").tag(MainTabs.directMessages)
//        Label("Search", systemImage: "magnifyingglass").tag(MainTabs.search)
//        Label("Me", systemImage: "person.text.rectangle").badge(1).tag(MainTabs.me)
//        Label("Canned Timeline", systemImage: "oilcan").tag(MainTabs.cannedTimeline)

}
