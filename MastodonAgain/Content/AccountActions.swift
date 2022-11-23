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
        .task {
            await errorHandler {
                _ = try await updateRelationship()
            }
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
                    var relationship = relationship
                    if relationship == nil {
                        relationship = try await updateRelationship()
                    }
                    guard let relationship else {
                        fatalError()
                    }
                    if !relationship.following {
                        _ = try await instanceModel.service.perform { baseURL, token in
                            MastodonAPI.Accounts.Follow(baseURL: baseURL, token: token, id: account.id)
                        }
                    }
                    else {
                        _ = try await instanceModel.service.perform { baseURL, token in
                            MastodonAPI.Accounts.Unfollow(baseURL: baseURL, token: token, id: account.id)
                        }
                    }
                    try await updateAccount()
                    try await updateRelationship()
                }
            }
            .highlighted(value: relationship?.following ?? false)
            .inflight(value: inflight.wrappedValue)
        }
    }

    @discardableResult
    func updateAccount() async throws -> Account {
        let account = try await instanceModel.service.perform { baseURL, token in
            MastodonAPI.Accounts.Retrieve(baseURL: baseURL, token: token, id: account.id)
        }
        await MainActor.run {
            self.account = account
        }
        return account
    }

    @discardableResult
    func updateRelationship() async throws -> Relationship {
        let relationship = try await instanceModel.service.perform { baseURL, token in
            MastodonAPI.Accounts.Relationships(baseURL: baseURL, token: token, ids: [account.id])
        }
        await MainActor.run {
            self.relationship = relationship.first! // TODO
        }
        return relationship.first! // TODO
    }
}
