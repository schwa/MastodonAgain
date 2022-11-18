import Blueprint
import Everything
import Foundation
import TabularData

public extension Service {
    func massFollow(csvFile: URL) async throws {
        let data = try DataFrame(contentsOfCSVFile: csvFile)
        guard let columnIndex = data.indexOfColumn("Account address") else {
            throw GeneralError.unknown
        }
        let column = data.columns[columnIndex]
        let usernames = column.compactMap({ $0 as? String })
        try await massFollow(usernames: usernames)
    }

    func followAccount(_ account: Account) async throws {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        _ = try await session.perform(MastodonAPI.Accounts.Follow(baseURL: baseURL, token: token, id: account.id))
    }

    func myAccount() async throws -> Account {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        return try await session.perform(MastodonAPI.Accounts.Verify(baseURL: baseURL, token: token)) as! Account
    }

    func searchAccount(_ username: String) async throws -> Account? {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        let results = try await session.perform(MastodonAPI.Accounts.Search(baseURL: baseURL, token: token, query: username, limit: 1, resolve: true)) as! [Account]
        return results.first
    }

    // TODO: function name is misleading. "accounts (this) account is following"
    func following(_ account: Account) async throws -> [Account] {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        return try await session.perform(MastodonAPI.Accounts.Following(baseURL: baseURL, token: token, id: account.id, limit: 1000)) as! [Account]
    }

    func massFollow(usernames: [String]) async throws {
        let me = try await myAccount()
        print(me)

        let following = try await following(me)
        print(following)

        let localUsernames = usernames.filter { $0.hasSuffix(host) }
        for username in localUsernames {
            print(username)
            if let account = try await searchAccount(username) {
                try await followAccount(account)
                print("success?")
            }
        }
    }
}
