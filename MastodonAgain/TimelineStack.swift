import SwiftUI
import Mastodon
import Everything

class StackModel: ObservableObject {
    @Published
    var path: [NavigationPage] = []

    enum NavigationPage: Hashable {
        case timeline(Timeline)
        case status(Status.ID)
        case account(Account.ID)
    }
}

struct TimelineStack: View {
    @EnvironmentObject
    var appModel: AppModel

    @StateObject
    var stackModel = StackModel()

    let timeline: Timeline

    init(timeline: Timeline) {
        self.timeline = timeline
    }

    var body: some View {
        NavigationStack(path: $stackModel.path) {
            TimelineView(timeline: timeline)
                .id(timeline)
                .navigationTitle(timeline.timelineType.title)
                .navigationDestination(for: StackModel.NavigationPage.self) { page in
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
                    }
                }
        }
        .environmentObject(appModel)
        .environmentObject(stackModel)
    }
}
