import Mastodon
import SwiftUI

struct StasusesView: View {
    @EnvironmentObject
    var instanceModel: InstanceModel

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var content = PagedContent<Fetch<Status>>()

    @State
    var isFetching = false

    let id: Account.ID

    init(id: Account.ID) {
        self.id = id
    }

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
        let request = MastodonAPI.Accounts.Statuses(baseURL: instanceModel.baseURL, token: instanceModel.token!, id: id, excludeReblogs: nil, tagged: nil)
        return Fetch(Status.self, service: instanceModel.service, request: request)
    }
}
