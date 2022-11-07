import Everything
import Mastodon
import SwiftUI

enum NavigationPage: Hashable {
    case timeline(Timeline)
    case status(Status.ID)
    case account(Account.ID)
    case me
}

class StackModel: ObservableObject {
    @Published
    var path: [NavigationPage] = []
}

struct TimelineStack: View {
    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @StateObject
    var stackModel = StackModel()

    let root: NavigationPage

    init(root: NavigationPage) {
        self.root = root
    }

    var body: some View {
        NavigationStack(path: $stackModel.path) {
            view(for: root)
                .navigationDestination(for: NavigationPage.self) { page in
                    view(for: page)
                }
        }
        .environmentObject(appModel)
        .environmentObject(stackModel)
    }

    @ViewBuilder
    func view(for page: NavigationPage) -> some View {
        switch page {
        case .timeline(let timeline):
            TimelineView(timeline: timeline)
                .id(timeline)
                .navigationTitle(timeline.timelineType.title)
        case .status(let status):
            StatusInfoView(id: status)
                .id(status)
                .navigationTitle("Status \(status.rawValue)")
        case .account(let account):
            AccountInfoView(id: account)
                .id(account)
        case .me:
            MeAccountInfoView()
        }
    }
}
