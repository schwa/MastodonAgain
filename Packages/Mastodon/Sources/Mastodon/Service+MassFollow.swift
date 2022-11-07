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
        let url = URL(string: "https://\(host)/api/v1/accounts/\(account.id.rawValue)/follow")!
        let request = URLRequest.post(url).headers(token.headers)
        _ = try await session.validatedData(for: request)
        // TODO: check following = true i suppose?
    }

    func myAccount() async throws -> Account {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        let url = URL(string: "https://\(host)/api/v1/accounts/verify_credentials")!
        let request = URLRequest(url: url).headers(token.headers)
        let (data, _) = try await session.validatedData(for: request)
        return try decoder.decode(Account.self, from: data)
    }

    func searchAccount(_ username: String) async throws -> Account? {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        // https://mastodon.example/api/v1/statuses/:id
        let url = URL(string: "https://\(host)/api/v1/accounts/search?q=\(username)&limit=1&resolve=true")!
        let request = URLRequest(url: url).headers(token.headers)
        let (data, _) = try await session.validatedData(for: request)
        let accounts = try decoder.decode([Account].self, from: data)
        return accounts.first
    }

    // TODO: function name is misleading. "accounts (this) account is following"
    func following(_ account: Account) async throws -> [Account] {
        guard let token = authorization.token else {
            fatalError("No host or token.")
        }
        let url = URL(string: "https://\(host)/api/v1/accounts/\(account.id.rawValue)/following?limit=1000")!
        let request = URLRequest(url: url).headers(token.headers)
        let (data, _) = try await session.validatedData(for: request)
        return try decoder.decode([Account].self, from: data)
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
