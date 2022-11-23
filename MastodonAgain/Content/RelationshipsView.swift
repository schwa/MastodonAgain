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
                    for try await relationships in await instanceModel.service.broadcaster(for: .relationships, element: [Account.ID: Relationship].self).makeChannel() {
                        appLogger?.log("XXX: Got \(relationships.count) relationships from storage")
                        await MainActor.run {
                            self.relationships.merge(relationships) { _, rhs in
                                rhs
                            }
                        }
                    }
                }
                try await instanceModel.service.fetchRelationship()
            }
        }
    }
}
