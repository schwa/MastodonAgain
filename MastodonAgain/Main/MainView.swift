import Everything
import Mastodon
import SwiftUI



struct MainView: View {
    @SceneStorage("columnVisibility")
    var columnVisibility: NavigationSplitViewVisibility = .automatic

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @State
    var selection: MainTabs? = MainTabs.home


    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                SignInPicker()
                Divider()

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
            switch selection {
            case .public, .federated, .home, .local:
                let timeline = Timeline(host: instanceModel.signin.host, timelineType: selection!.timelineType!)
                TimelineStack(root: .timeline(timeline))
            case .me:
                TimelineStack(root: .me)
            default:
                NotificationsView()
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbar {
            Toggle("Debug", isOn: $appModel.showDebuggingInfo)
                .toggleStyle(ImageToggleStyle())
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
    case me
    case notifications

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
        case (.me, nil):
            return "Me"
        case (.notifications, nil):
            return "Notifications"
        default:
            fatalError("Fallthrough")
        }
    }

    var image: Image {
        switch (self, timelineType) {
        case (_, .some(let timeline)):
            return timeline.image
        case (.me, nil):
            return Image(systemName: "person")
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
}
