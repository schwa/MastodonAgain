import Everything
import Mastodon
import SwiftUI

struct TimelineView: View {
    @Environment(\.errorHandler)
    var errorHandler

    @EnvironmentObject
    var appModel: AppModel

    @State
    var timeline: Timeline

    @State
    var pages = StatusesPagedContent()

    @State
    var refreshing = false

    init(timeline: Timeline) {
        self._timeline = State(initialValue: timeline)
    }

    @ViewBuilder
    var body: some View {
        DescriptionView(timeline).debuggingInfo()
        DescriptionView(pages).debuggingInfo()
//        Group {
//            if refreshing {
//                ProgressView()
//            }
//            else {
//                List() {
//                    PagedContentView(content: $pages) { status in
//                        StatusRow(status: status)
//                    }
//                }
//            }
//        }
//        .refreshable {
//            refreshTask()
//        }
//        .toolbar {
//            Button("Save") {
//                do {
//                    let data = try JSONEncoder().encode(timeline)
//                    let path = FSPath.temporaryDirectory / "timeline.json"
//                    try data.write(to: path.url)
//                    path.reveal()
//                }
//                catch {
//                    fatal(error: error)
//                }
//            }
//
//            Button("Refresh") {
//                refreshTask()
//            }
//            .disabled(refreshing)
//        }
//        .task {
//            refreshTask()
//        }
    }

    func refreshTask(direction: PagingDirection? = nil) {
        guard timeline.timelineType != .canned else {
            return
        }
        refreshing = true
        Task {
            await errorHandler.handle {
                try await refresh(direction: direction)
            }
            refreshing = false
        }
    }

    func refresh(direction: PagingDirection? = nil) async throws {
        //timeline = try await appModel.service.timelime(timeline, direction: direction)
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
