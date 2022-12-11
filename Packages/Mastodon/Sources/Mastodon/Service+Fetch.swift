import AsyncAlgorithms
import Blueprint
import Everything
import Foundation
import SwiftUI

public extension Service {
    // TODO: String keys.

    func fetchAllKnownRelationships() async throws {
        let relationships = try await storage.get(key: "relationships") ?? [Account.ID: Relationship]()
        await broadcaster(for: .relationships, element: [Account.ID: Relationship].self).broadcast(relationships)
    }

    func fetchRelationships(ids: [Account.ID], remoteOnly: Bool = false) async throws {
        // De-dupe input.
        let ids = Array(Set(ids))
        // We're gonna be broadcasting the shit out of these relationships.
        let broadcaster = broadcaster(for: .relationships, element: [Account.ID: Relationship].self)
        let storedRelationships = try await storage.get(key: "relationships") ?? [Account.ID: Relationship]()
        if !remoteOnly {
            // Get relationships we already know about that match input and broadcast them.
            let relationships = storedRelationships.filter({ ids.contains($0.key) })
            if !relationships.isEmpty {
                await broadcaster.broadcast(relationships)
            }
        }
        Task {
            // Fetch relationships from server.
            let newRelationships = try await perform { baseURL, token in
                MastodonAPI.Accounts.Relationships(baseURL: baseURL, token: token, ids: ids)
            }
            // Merge all new relationships with all stored relationships
            let allRelationships = storedRelationships.merging(zip(newRelationships.map(\.id), newRelationships)) { _, rhs in
                rhs
            }
            // Broadcast all relationships that match input
            let filteredRelationships = allRelationships.filter({ ids.contains($0.key) })
            if !filteredRelationships.isEmpty {
                await broadcaster.broadcast(filteredRelationships)
            }
            // Save all relationships to disk
            try await storage.set(key: "relationships", value: allRelationships)
        }
    }
}
