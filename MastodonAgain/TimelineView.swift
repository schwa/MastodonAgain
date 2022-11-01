import Everything
import Mastodon
import SwiftUI

// TODO: Sendable view?
struct TimelineView: View, Sendable {
    @Environment(\.errorHandler)
    var errorHandler

    @EnvironmentObject
    var appModel: AppModel

    let timeline: Timeline

    @State
    var content = PagedContent<Status>()

    @State
    var refreshing = false

    init(timeline: Timeline) {
        self.timeline = timeline
    }

    @ViewBuilder
    var body: some View {
        Group {
            List() {
                DebugDescriptionView(timeline.url).debuggingInfo()
                if refreshing {
                    ProgressView()
                }

                PagedContentView(content: $content, isFetching: $refreshing) { status in
                    StatusRow(status: status)
                    Divider()
                }
            }
        }
//        .refreshable {
//            // TODO: How to get this to work on macOS?
//            refreshTask()
//        }
        .toolbar {
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
            await errorHandler.handle { [appModel, timeline] in
                guard await appModel.instance.token != nil else {
                    return
                }
                let page = try await appModel.service.timelime(timeline)
                appLogger?.log("Fetched page: \(page.debugDescription)")
                await MainActor.run {
                    content.pages = [page]
                }
            }
            refreshing = false
        }
    }
}

//struct PageView: View {
//    @Binding
//    var page: Timeline.Page
//
//    var body: some View {
//        pageDebugInfo(page)
//        ForEach(page.statuses) { status in
//            let id = status.id
//            let binding = Binding {
//                status
//            } set: { newValue in
//                guard let index = page.statuses.firstIndex(where: { $0.id == id }) else {
//                    fatalError("Could not find a status in a page we were displaying it from...")
//                }
//                page.statuses[index] = newValue
//            }
//            StatusRow(status: binding)
//            Divider()
//        }
//    }
//
//    @ViewBuilder
//    func pageDebugInfo(_ page: Timeline.Page) -> some View {
//        HStack {
//            VStack {
//                Text(verbatim: "id: \(page.id)").frame(maxWidth: .infinity)
//                Text(verbatim: "previous: \(page.previous?.absoluteString ?? "<none>")")
//                Text(verbatim: "next: \(page.next?.absoluteString ?? "<none>")")
//            }
//            if let data = page.data {
//                Button("Save") {
//                    let path = FSPath.temporaryDirectory / "page.json"
//                    try! data.write(to: path.url)
//                    path.reveal()
//                }
//            }
//        }
//        .debuggingInfo()
//    }
//}
