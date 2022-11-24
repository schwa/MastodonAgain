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

    var body: some View {
        Text("Placeholder")
    }
}
