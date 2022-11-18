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
    var content = PagedContent<Status>()

    enum Mode: String, RawRepresentable, CaseIterable, Sendable {
        case small
        case large
    }

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
            DebugDescriptionView(timeline.url).debuggingInfo()
            if refreshing {
                ProgressView()
            }

            PagedContentView(content: $content, isFetching: $refreshing) { status in
                if appModel.statusRowMode == .large {
                    StatusRow(status: status)
                    Divider()
                }
                else {
                    MiniStatusRow(status: status)
                }
            }
        }
        .toolbar {
            Picker("Mode", selection: $appModel.statusRowMode) {
                Image(systemName: "tablecells").tag(Mode.large)
                Image(systemName: "list.dash").tag(Mode.small)
            }
            .pickerStyle(.inline)

            Button("Save") {
                do {
                    let data = try JSONEncoder().encode(timeline)
                    let path = FSPath.temporaryDirectory / "timeline.json"
                    try data.write(to: path.url)
                    #if os(macOS)
                        path.reveal()
                    #endif
                }
                catch {
                    fatal(error: error)
                }
            }
        }
        .task {
            refreshTask()
        }
    }

    func refreshTask(direction: PagingDirection? = nil) {
        guard refreshing == false else {
            return
        }
        guard timeline.timelineType != .canned else {
            return
        }
        refreshing = true
        Task {
            await errorHandler { [instanceModel, timeline] in
                guard await instanceModel.signin.authorization.token != nil else {
                    return
                }
                let page = try await instanceModel.service.timelime(timeline)
                appLogger?.log("Fetched page: \(page.debugDescription)")
                await MainActor.run {
                    content.pages = [page]
                }
            }
            refreshing = false
        }
    }
}

