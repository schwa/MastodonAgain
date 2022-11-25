import Mastodon
import SwiftUI

struct StatusInfoView: View {
    let id: Status.ID

    @State
    var status: Status?

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    init(_ id: Status.ID) {
        self.id = id
    }

    var body: some View {
        Group {
            if status != nil {
                LargeStatusRow(status: $status.unsafeBinding())
            }
            else {
                ProgressView()
            }
        }
        .task {
            Task {
                let channel = await instanceModel.service.broadcaster(for: .status(id), element: Status.self).makeChannel()
                for await status in channel {
                    await MainActor.run {
                        self.status = status
                    }
                }
            }
            self.status = try? await instanceModel.service.fetchStatus(id: id)
        }
    }
}
