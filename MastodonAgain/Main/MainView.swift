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
            Spacer()
//            router.label(for: )
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
    var id: PageID { get}
    var subject: Subject { get}
}

struct Page <Subject>: PageProtocol {
    let id: PageID
    let subject: Subject

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

typealias AnyPage = Page<Any>

extension Page where Subject == Any {
    init<Base>(_ base: Base) where Base: PageProtocol {
        self.id = base.id
        self.subject = base.subject
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
    associatedtype Subject
    associatedtype Label_: View

    var label: Label_ { get }

    init(_ subject: Subject)
}

// MARK: -

struct Router {
    let root: [AnyPage] = [
        Page(id: .homeTimeline, subject: Timeline.home),
        Page(id: .localTimeline, subject: Timeline.local),
        Page(id: .publicTimeline, subject: Timeline.public),
        Page(id: .federatedTimeline, subject: Timeline.federated),
        Page(id: .notifications, subject: ()),
        Page(id: .relationships, subject: ()),
        Page(id: .account, subject: Account.ID?.none as Any),
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
            let subject = page.subject as! Timeline
            return TimelineView(subject)
        case .notifications:
            return NotificationsView()
        case .relationships:
            return RelationshipsView()
        case .account:
            let id = page.subject as? Account.ID
            return AccountInfoView(id)
        case .status:
            let id = page.subject as? Status.ID
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
    init(_ subject: ()) {
        self.init()
    }
}

extension RelationshipsView: PageView {
    var label: some View {
        Label("Relationships", systemImage: "gear")
    }
    init(_ subject: ()) {
        self.init()
    }
}

extension AccountInfoView: PageView {
    typealias subject = Account.ID?
    var label: some View {
        Label("Account", systemImage: "gear")
    }
}

extension StatusInfoView: PageView {
    typealias subject = Status.ID?
    var label: some View {
        Label("Status", systemImage: "gear")
    }
}
