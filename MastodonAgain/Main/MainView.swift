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
            SignInPicker()

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
            switch selection {
            case .public, .federated, .home, .local:
                let timeline = Timeline(host: instanceModel.signin.host, timelineType: selection!.timelineType!)
                TimelineStack(root: .timeline(timeline))
            case .me:
                TimelineStack(root: .me)
            case .notifications:
                NotificationsView()
#if os(iOS)
            case .settings:
                AppSettings()
#endif
            default:
                EmptyView() // TODO: Why are we getting nil for selection?
            }
        }
        .toolbar {
            Toggle("Debug", isOn: $appModel.showDebuggingInfo)
                .toggleStyle(ImageToggleStyle())
        }
        .overlay(alignment: .bottomLeading) {
            VStack(spacing: 2) {
                // swiftlint:disable force_cast

                Link(destination: "https://github.com/schwa/MastodonAgain/issues/new") {
                    VStack {
                        Label("File a bug…", systemImage: "ladybug")
                        Text("(Build #\(Bundle.main.infoDictionary!["CFBundleVersion"] as! String))")
                    }
                }
            }
            .padding(4)
            .background(Color.orange.opacity(0.75).cornerRadius(8))
            .padding()
        }
    }
}

enum MainTabs: String, CaseIterable {
    case home
    case `public`
    case federated
    case local
    case me
    case notifications
#if os(iOS)
    case settings
#endif

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
        case (.me, nil):
            return "Me"
        case (.notifications, nil):
            return "Notifications"
#if os(iOS)
        case (.settings, nil):
            return "Settings"
#endif
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
#if os(iOS)
        case (.settings, nil):
            return Image(systemName: "gear")
#endif
        default:
            return Image(systemName: "gear")
        }
    }
}
