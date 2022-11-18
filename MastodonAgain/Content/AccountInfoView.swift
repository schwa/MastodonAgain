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

    @EnvironmentObject
    var instanceModel: InstanceModel

    init(id: Account.ID) {
        self.id = id
    }

    init(account: Account) {
        id = account.id
        self.account = account
    }

    @State
    var primaryTabSelection: Int = 1

    var body: some View {
        FetchableValueView(value: account, canRefresh: false) { [instanceModel, id] in
            var account = await instanceModel.service.account(for: id)
            if account == nil {
                account = try await instanceModel.service.fetchAccount(for: id)
            }
            return account
        } content: { account in
            VStack {
                VStack {
                    Divider()
                    DebugDescriptionView(account)
                }.debuggingInfo()
                Avatar(account: account)
                    .frame(maxWidth: 128, maxHeight: 128, alignment: .center)
                Text(verbatim: account.displayName).bold()
                HStack {
                    Text(verbatim: "@\(account.acct)@\(instanceModel.signin.host)")
                    if account.locked {
                        Image(systemName: "lock")
                    }
                }
                Text(verbatim: account.note)
                LabeledContent("Joined") {
                    Text(account.created, style: .date)
                }
                Grid {
                    ForEach(account.fields.indices, id: \.self) { index in
                        GridRow {
                            let field = account.fields[index]
                            Text(field.name)
                            Text(field.value)
                        }
                    }
                }

                HStack {
                    Button {
                        primaryTabSelection = 1
                    } label: {
                        LabeledContent("Posts", value: "\(account.statusesCount, format: .number)")
                    }
                    Button {
                        primaryTabSelection = 2
                    } label: {
                        LabeledContent("Following", value: "\(account.followingCount, format: .number)")
                    }
                    Button {
                        primaryTabSelection = 3
                    } label: {
                        LabeledContent("Followers", value: "\(account.followersCount, format: .number)")
                    }
                }

                SelectedView(selection: primaryTabSelection) {
                    posts.selection(1)
                    following.selection(2)
                    followers.selection(3)
                }
            }
            .navigationTitle("\(account.displayName)")
            .padding()
        }
    }

    @ViewBuilder
    var posts: some View {
        PlaceholderShape().stroke()
    }

    @ViewBuilder
    var following: some View {
        PlaceholderShape().stroke()
    }

    @ViewBuilder
    var followers: some View {
        PlaceholderShape().stroke()
    }
}

// MARK: -

struct MeAccountInfoView: View {
    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    var body: some View {
        FetchableValueView { [instanceModel] in
            try await instanceModel.service.myAccount()
        } content: { account in
            AccountInfoView(account: account)
        }
    }
}
