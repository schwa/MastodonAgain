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
    var selection: AnyPage?

    @Environment(\.announcer)
    var announcer

    let router = Router()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, sidebar: { sidebar }, detail: { detail })
            .toolbar {
                Toggle("Debug", isOn: $appModel.showDebuggingInfo)
                    .toggleStyle(ImageToggleStyle())
            }
            .overlay(alignment: .bottomTrailing) {
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
            .onAppear {
                router.appModel = appModel
                router.instanceModel = instanceModel
                selection = router.root.first
            }
    }

    @ViewBuilder
    var sidebar: some View {
        SignInPicker().padding([.leading, .trailing])

        List(selection: $selection) {
            ForEach(router.root, id: \.self) { id in
                router.label(for: id)
            }
        }
    }

    @ViewBuilder
    var detail: some View {
        if let selection {
            NavStack(router: router, root: selection)
        }
    }
}

class StackModel: ObservableObject {
    @Published
    // TODO: we want this to be ui state
    var path: [AnyPage] = []
}

struct NavStack: View {
    let router: Router

    let root: AnyPage

    @StateObject
    var model = StackModel()

    init(router: Router, root: AnyPage) {
        self.router = router
        self.root = root
    }

    var body: some View {
        NavigationStack(path: $model.path) {
            router.view(for: root).id(root.id)
        }
        .navigationDestination(for: AnyPage.self) { page in
            router.view(for: page).id(page.id)
        }
        .environmentObject(model)
    }
}

protocol PageProtocol: Identifiable, Hashable {
    associatedtype Subject
    var id: PageID { get }
    var subject: Subject { get }
}

struct Page<Subject>: PageProtocol {
    let id: PageID
    let subject: Subject

    init(id: PageID, subject: Subject) {
        self.id = id
        self.subject = subject
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

typealias AnyPage = Page<Any>

extension Page where Subject == Any {
    init(_ base: some PageProtocol) {
        id = base.id
        subject = base.subject
    }
}

extension Page {
    func eraseToAnyPage() -> AnyPage {
        AnyPage(self)
    }
}

enum PageID: CaseIterable {
    case homeTimeline
    case publicTimeline
    case localTimeline
    case federatedTimeline
    case notifications
    case relationships
    case account
    case status
    #if os(macOS)
        case log
    #endif
    case bookmarks
    case statuses
}

// MARK: -

@MainActor
class Router {
    var root: [AnyPage] = [
        Page(id: .homeTimeline, subject: Timeline.home),
        Page(id: .localTimeline, subject: Timeline.local),
        Page(id: .publicTimeline, subject: Timeline.public),
        Page(id: .federatedTimeline, subject: Timeline.federated),
        Page(id: .notifications, subject: ()),
        Page(id: .relationships, subject: ()),
        Page(id: .account, subject: Account.ID?.none as Any),
        Page(id: .bookmarks, subject: ()),
        Page(id: .statuses, subject: ()),
    ]

    var appModel: AppModel?
    var instanceModel: InstanceModel?

    init() {
//        #if os(macOS)
//        root.append(Page(id: .log, subject: ()))
//        #endif
    }

    @ViewBuilder
    func label(for page: AnyPage) -> some View {
        switch page.id {
        case .homeTimeline, .localTimeline, .publicTimeline, .federatedTimeline:
            (page.subject as! Timeline).label
        case .notifications:
            Label("Notifications", systemImage: "gear")
        case .relationships:
            Label("relationships", systemImage: "gear")
        case .account:
            // Name varies depending on subject
            Label("Account", systemImage: "gear")
        case .status:
            Label("Status", systemImage: "gear")
        #if os(macOS)
            case .log:
                Label("Log", systemImage: "gear")
        #endif
        case .bookmarks:
            Label("Bookmarks", systemImage: "gear")
        case .statuses:
            Label("Stasuses", systemImage: "gear")
        }
    }

    @ViewBuilder
    func view(for page: AnyPage) -> some View {
        switch page.id {
        case .homeTimeline, .localTimeline, .publicTimeline, .federatedTimeline:
            let subject = page.subject as! Timeline
            TimelineView(subject).eraseToAnyView()
        case .notifications:
            NotificationsView()
        case .relationships:
            RelationshipsView()
        case .account:
            let id = page.subject as? Account.ID
            AccountInfoView(id)
        case .status:
            let id = page.subject as! Status.ID
            StatusInfoView(id)
        #if os(macOS)
            case .log:
                ConsoleLogView()
        #endif
        case .bookmarks:
            BookmarksView()
        case .statuses:
            StasusesView(id: instanceModel!.signin.account.id)
        }
    }
}
