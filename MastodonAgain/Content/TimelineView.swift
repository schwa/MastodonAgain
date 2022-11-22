import Everything
import Mastodon
import SwiftUI

// TODO: Sendable view?
struct TimelineView: View, Sendable {
    @Environment(\.errorHandler)
    var errorHandler

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    let timeline: Timeline

    @State
    var content = PagedContent<Fetch<Status>>()

    @State
    var refreshing = false

    init(timeline: Timeline) {
        self.timeline = timeline
    }

    @State
    var selection: Set<Status.ID> = []

    @StateObject
    var stackModel = StackModel()

    @ViewBuilder
    var body: some View {
        List(selection: $selection) {
            DebugDescriptionView(timeline).debuggingInfo()
            PagedContentView(content: $content, isFetching: $refreshing) { status in
                StatusRow(status: status, mode: appModel.statusRowMode)
                    .isSelected(selection.contains(status.id))
            }
            .listSectionSeparator(.visible, edges: .bottom)
        }
        .toolbar {
            Button("Refresh") {
                guard refreshing == false else {
                    return
                }
                refreshTask()
            }
            .keyboardShortcut(.init("R", modifiers: .command))
            .disabled(refreshing)

            Picker("Mode", selection: $appModel.statusRowMode) {
                Image(systemName: "tablecells").tag(StatusRow.Mode.large)
                Image(systemName: "list.dash").tag(StatusRow.Mode.mini)
                Image(systemName: "list.bullet.below.rectangle").tag(StatusRow.Mode.alt)
            }
            .pickerStyle(.inline)

            ValueView(value: false) { value in
                Button("Save") {
                    value.wrappedValue = true
                }
                // swiftlint:disable:next force_try
                .fileExporter(isPresented: value, document: try! JSONDocument(content), contentType: .json) { _ in }
            }
        }
        .task {
            /* TODO: Bug this is getting called multiple times (x2). The guard isn't preventing multiple hits. Also seeing
             Update NavigationAuthority bound path tried to update multiple times per frame.
             Update NavigationRequestObserver tried to update multiple times per frame.
             https://developer.apple.com/forums/thread/708592
             */
            guard refreshing == false else {
                return
            }
            refreshTask()
        }
    }

    func refreshTask(direction: PagingDirection? = nil) {
        appLogger?.log("FETCHING PAGE (once per timelime)")
        guard refreshing == false else {
            return
        }
        refreshing = true
        Task {
            await errorHandler { [instanceModel, timeline] in
                guard await instanceModel.signin.authorization.token != nil else {
                    return
                }
                let page = try await instanceModel.service.timelime(timeline)
                guard !page.elements.isEmpty else {
                    return
                }
                appLogger?.log("Fetched page: \(page.debugDescription)")
                await MainActor.run {
                    guard !content.pages.contains(where: { $0.id == page.id }) else {
                        appLogger?.log("Paged content already contains page \(FunHash(page.id).description)")
                        return
                    }
                    let page = content.reducePageToFit(page)
                    content.pages.insert(page, at: 0)
                }
            }
            refreshing = false
        }
    }
}

struct SelectedKey: EnvironmentKey {
    static var defaultValue = false
}

extension EnvironmentValues {
    var isSelected: Bool {
        get {
            self[SelectedKey.self]
        }
        set {
            self[SelectedKey.self] = newValue
        }
    }
}

struct SelectedModifier: ViewModifier {
    let value: Bool
    func body(content: Content) -> some View {
        content.environment(\.isSelected, value)
    }
}

extension View {
    func isSelected(_ value: Bool) -> some View {
        modifier(SelectedModifier(value: value))
    }
}
