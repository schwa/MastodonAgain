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
            selection = router.root.first
        }
    }

    @ViewBuilder
    var sidebar: some View {
        SignInPicker()

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
    associatedtype Content
    var id: PageID { get}
    var content: Content { get}
}

struct Page <Content>: PageProtocol {
    let id: PageID
    let content: Content

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

typealias AnyPage = Page<Any>

extension Page where Content == Any {
    init<Base>(_ base: Base) where Base: PageProtocol {
        self.id = base.id
        self.content = base.content
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
}

protocol PageView: View {
    associatedtype Content
    associatedtype Label_: View

    var label: Label_ { get }

    init(_ content: Content)
}

// MARK: -

struct Router {
    let root: [AnyPage] = [
        Page(id: .homeTimeline, content: Timeline.home).eraseToAnyPage(),
        Page(id: .localTimeline, content: Timeline.local).eraseToAnyPage(),
        Page(id: .publicTimeline, content: Timeline.public).eraseToAnyPage(),
        Page(id: .federatedTimeline, content: Timeline.federated).eraseToAnyPage(),
        Page(id: .notifications, content: ()).eraseToAnyPage(),
        Page(id: .relationships, content: ()).eraseToAnyPage(),
        Page(id: .account, content: Account.ID?.none).eraseToAnyPage(),
    ]

    func label(for page: AnyPage) -> some View {
        pageView(for: page).label.eraseToAnyView()
    }

    func view(for page: AnyPage) -> some View {
        pageView(for: page).eraseToAnyView()
    }

    func pageView(for page: AnyPage) -> any PageView {
        switch page.id {
        case .homeTimeline, .localTimeline, .publicTimeline, .federatedTimeline:
            let content = page.content as! Timeline
            return TimelineView(content)
        case .notifications:
            return NotificationsView()
        case .relationships:
            return RelationshipsView()
        case .account:
            let id = page.content as? Account.ID
            return AccountInfoView(id)
        case .status:
            let id = page.content as? Status.ID
            return StatusInfoView(id)
        }
    }
}

extension TimelineView: PageView {
    var label: some View {
        Label(timeline.title, systemImage: timeline.systemImageName)
    }
}

extension NotificationsView: PageView {
    var label: some View {
        Label("Notifications", systemImage: "gear")
    }
    init(_ content: ()) {
        self.init()
    }
}

extension RelationshipsView: PageView {
    var label: some View {
        Label("Relationships", systemImage: "gear")
    }
    init(_ content: ()) {
        self.init()
    }
}

extension AccountInfoView: PageView {
    typealias content = Account.ID?
    var label: some View {
        Label("Account", systemImage: "gear")
    }
}

extension StatusInfoView: PageView {
    typealias content = Status.ID?
    var label: some View {
        Label("Status", systemImage: "gear")
    }
}
