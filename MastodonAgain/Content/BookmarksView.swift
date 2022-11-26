import Mastodon
import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject
    var instanceModel: InstanceModel

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var content = PagedContent<Fetch<Status>>()

    @State
    var isFetching = false

    var body: some View {
        List {
            PagedContentView(content: $content, isFetching: $isFetching) { status in
                MiniStatusRow(status: status)
            }
        }
        .task {
            await errorHandler {
                let page = try await fetch()
                await MainActor.run {
                    self.content.pages = [page]
                }
            }
        }
    }

    var fetch: Fetch<Status> {
        let request = MastodonAPI.Bookmarks.View(baseURL: instanceModel.baseURL, token: instanceModel.token!)
        return Fetch(Status.self, service: instanceModel.service, request: request)
    }
}
