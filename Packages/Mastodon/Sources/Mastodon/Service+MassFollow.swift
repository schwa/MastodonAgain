import Blueprint
import Everything
import Foundation
import TabularData

public extension Service {
    @available(*, deprecated, message: "Use MastodonAPI directly")
    func followAccount(_ account: Account) async throws {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        _ = try await session.perform(MastodonAPI.Accounts.Follow(baseURL: baseURL, token: token, id: account.id))
    }

    @available(*, deprecated, message: "Use MastodonAPI directly")
    func myAccount() async throws -> Account {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        // swiftlint:disable:next force_cast
        return try await session.perform(MastodonAPI.Accounts.Verify(baseURL: baseURL, token: token)) as! Account
    }

    @available(*, deprecated, message: "Use MastodonAPI directly")
    func searchAccount(_ username: String) async throws -> Account? {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        // swiftlint:disable:next force_cast
        let results = try await session.perform(MastodonAPI.Accounts.Search(baseURL: baseURL, token: token, query: username, limit: 1, resolve: true)) as! [Account]
        return results.first
    }

    // TODO: function name is misleading. "accounts (this) account is following"
    func following(_ account: Account) async throws -> [Account] {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        // swiftlint:disable:next force_cast
        return try await session.perform(MastodonAPI.Accounts.Following(baseURL: baseURL, token: token, id: account.id, limit: 1000)) as! [Account]
    }
}
