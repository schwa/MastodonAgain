import Mastodon
import SwiftUI

struct StatusInfoView: View {
    let id: Status.ID

    @State
    var status: Status?

    @EnvironmentObject
    var appModel: AppModel

    var body: some View {
        if let status {
            DebugDescriptionView(status)
                .padding()
        }
        else {
            ProgressView()
                .task {
                    status = await appModel.service.status(for: id)
                }
        }
    }
}
