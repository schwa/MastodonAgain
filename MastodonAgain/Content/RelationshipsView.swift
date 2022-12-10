import Everything
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
                try await instanceModel.service.fetchAllKnownRelationships()
            }
        }
        List(Array(relationships.values)) { relationship in
            DebugDescriptionView(relationship)
                .listRowSeparator(.visible, edges: .bottom)
        }
        .task {
            let channel = await instanceModel.service.broadcaster(for: .relationships, element: [Account.ID: Relationship].self).makeChannel()
            await errorHandler {
                Task {
                    for try await relationships in channel {
                        await MainActor.run {
                            self.relationships.merge(relationships) { _, rhs in
                                rhs
                            }
                        }
                    }
                }
                try await instanceModel.service.fetchAllKnownRelationships()
            }
        }
    }
}
