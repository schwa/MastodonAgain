import Everything
import Mastodon
import SwiftUI

struct TimelineView: View {
    @Environment(\.errorHandler)
    var errorHandler

    @EnvironmentObject
    var appModel: AppModel

    let timeline: Timeline

    @State
    var pages = StatusesPagedContent()

    @State
    var refreshing = false

    init(timeline: Timeline) {
        self.timeline = timeline
    }

    @ViewBuilder
    var body: some View {
        Group {
            List() {
                if refreshing {
                    ProgressView()
                }

                PagedContentView(content: $pages, isFetching: $refreshing) { status in
                    StatusRow(status: status)
                }
            }
        }
//        .refreshable {
//            refreshTask()
//        }
        .toolbar {
            Button("Save") {
                do {
                    let data = try JSONEncoder().encode(timeline)
                    let path = FSPath.temporaryDirectory / "timeline.json"
                    try data.write(to: path.url)
                    path.reveal()
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
        guard timeline.timelineType != .canned else {
            return
        }
        refreshing = true
        Task {
            await errorHandler.handle {
                let page = try await appModel.service.timelime(timeline)
                self.pages.pages.append(page)
            }
            refreshing = false
        }
    }
}

struct DebugDescriptionView <Value>: View {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }

    var body: some View {
        Group {
            if let value = value as? CustomDebugStringConvertible {
                Text(verbatim: "\(value.debugDescription)")
            }
            else if let value = value as? CustomStringConvertible {
                Text(verbatim: "\(value.description)")
            }
            else {
                Text(verbatim: "\(String(describing: value))")
            }
        }
        .textSelection(.enabled)
        .font(.body.monospaced())
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
