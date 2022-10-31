import Mastodon
import SwiftUI

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

    @Published
    var showDebugInfo = true

    let service = Service()

    init() {
        instance = Storage.shared["instance"] ?? Instance("mastodon.social")
        Task {
            await service.update(instance: instance)
        }
    }
}

