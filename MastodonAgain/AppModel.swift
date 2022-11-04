import Mastodon
import SwiftUI

@MainActor
class AppModel: ObservableObject {
    @Published
    var instance: Instance {
        didSet {
            Storage.shared["instance"] = instance
            Task {
                await service.update(instance: instance)
            }
        }
    }

    @AppStorage("showDebuggingInfo")
    var showDebuggingInfo = false

    @AppStorage("hideSensitiveContent")
    var hideSensitiveContent = false

    @AppStorage("useMarkdownContent")
    var useMarkdownContent = false

    @AppStorage("StatusRowMode")
    var statusRowMode = TimelineView.Mode.large

    let service = Service()

    init() {
        instance = Storage.shared["instance"] ?? Instance("mastodon.social")
        Task {
            await service.update(instance: instance)
        }
    }
}

