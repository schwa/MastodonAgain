import Everything
import Mastodon
import SwiftUI

struct AccountActions: View {
    @Binding
    var account: Account

    @Binding
    var relationship: Relationship?

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @EnvironmentObject
    var stackModel: StackModel

    @Environment(\.errorHandler)
    var errorHandler

    var body: some View {
        Group {
            followButton
        }
        .buttonStyle(ActionButtonStyle())
        .task { [account] in
            let channel = await instanceModel.service.broadcaster(for: .relationships, element: [Account.ID: Relationship].self).makeChannel()
            await errorHandler {
                Task {
                    for try await relationships in channel {
                        await MainActor.run {
                            guard let relationship = relationships[account.id] else {
                                return
                            }
                            appLogger?.log("Got relationship update for \(account.id)")

                            self.relationship = relationship
                        }
                    }
                }
                appLogger?.log("Fetching relationship for: \(account.id)")
                try await instanceModel.service.fetchRelationships(ids: [account.id])
            }
        }
        .onChange(of: relationship) { _ in
            appLogger?.log("\(relationship.debugDescription)")
        }
    }

    @ViewBuilder
    var followButton: some View {
        ValueView(value: false) { inflight in
            Button(title: "Follow", systemImage: "person.crop.circle.fill.badge.plus") { [account, relationship] in
                inflight.wrappedValue = true
                await errorHandler {
                    defer {
                        inflight.wrappedValue = false
                    }
                    guard let relationship else {
                        fatalError("TODO")
                    }
                    if !relationship.following {
                        appLogger?.log("SENDING FOLLOW REQUEST")
                        let relationship = try await instanceModel.service.perform { baseURL, token in
                            MastodonAPI.Accounts.Follow(baseURL: baseURL, token: token, id: account.id)
                        }
                        await MainActor.run {
                            self.relationship = relationship
                        }
                    }
                    else {
                        appLogger?.log("SENDING UNFOLLOW REQUEST")
                        let relationship = try await instanceModel.service.perform { baseURL, token in
                            MastodonAPI.Accounts.Unfollow(baseURL: baseURL, token: token, id: account.id)
                        }
                        await MainActor.run {
                            self.relationship = relationship
                        }
                    }
                }
            }
            .contextMenu {
                Button("Refresh") {
                    await errorHandler {
                        try await instanceModel.service.fetchRelationships(ids: [account.id], remoteOnly: true)
                    }
                }
            }
            .disabled(relationship == nil)
            .highlighted(value: relationship?.following ?? false)
            .inflight(value: inflight.wrappedValue)
        }
    }

    // TODO: Currently crashing. But updateRelationship is fine? WTF?
    @discardableResult
    func updateAccount() async throws -> Account {
//        let account = try await instanceModel.service.perform { baseURL, token in
//            MastodonAPI.Accounts.Retrieve(baseURL: baseURL, token: token, id: account.id)
//        }
//        await MainActor.run {
//            self.account = account
//        }
//        return account
        account
    }
}
