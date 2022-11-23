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
        List(Array(relationships.values)) { relationship in
            DebugDescriptionView(relationship)
                .listRowSeparator(.visible, edges: .bottom)
        }
        .task {
            await errorHandler {
                Task {
                    appLogger?.log("XXX: Start awaiting")
                    for try await relationships in await instanceModel.service.relationshipChannel() {
                        appLogger?.log("XXX: Got \(relationships.count) relationships from storage")
                        await MainActor.run {
                            self.relationships.merge(relationships) { _, rhs in
                                return rhs
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
