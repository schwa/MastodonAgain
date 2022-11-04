import Everything
import Mastodon
import SwiftUI

struct AccountInfoView: View {
    let id: Account.ID

    @State
    var account: Account?

    @Environment(\.errorHandler)
    var errorHandler

    @EnvironmentObject
    var appModel: AppModel

    var body: some View {
        if let account {
            DebugDescriptionView(account)
                .navigationTitle("\(account.displayName)")
                .padding()
        }
        else {
            ProgressView()
                .navigationTitle("Account #\(id.rawValue)")
                .task {
                    account = await errorHandler { [appModel, id] in
                        var account = await appModel.service.account(for: id)
                        if account == nil {
                            account = try await appModel.service.fetchAccount(for: id)
                        }
                        return account
                    }
                }
        }
    }
}
