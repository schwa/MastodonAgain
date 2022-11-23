import Mastodon
import SwiftUI

struct RelationshipsView: View {
    @EnvironmentObject
    var instanceModel: InstanceModel

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var relationships: [Account.ID: Relationship] = [:]

    var body: some View {
        Text("\(relationships.count) relationships")
        Button("Reload") {
            Task {
                appLogger?.log("XXX: Requesting")
                try await instanceModel.service.fetchRelationship()
            }

        }
        List(Array(relationships.values)) { relationship in
            DebugDescriptionView(relationship)
                .listRowSeparator(.visible, edges: .bottom)
        }
        .task {
            await errorHandler {
                Task {
                    appLogger?.log("XXX: Start awaiting")
                    for try await relationships in await instanceModel.service.broadcaster(for: .relationships, element: [Account.ID: Relationship].self).makeChannel() {
                        appLogger?.log("XXX: Got \(relationships.count) relationships from storage")
                        await MainActor.run {
                            self.relationships.merge(relationships) { _, rhs in
                                rhs
                            }
                            appLogger?.log("XXX: Merged \(self.relationships.count) relationships.")
                        }
                    }
                }
                appLogger?.log("XXX: Requesting")
                try await instanceModel.service.fetchRelationship()
            }
        }
    }
}
