import Everything
import Mastodon
import SwiftUI

struct AccountInfoView: View {
    @State
    var id: Account.ID?

    @State
    var account: Account?

    @Environment(\.errorHandler)
    var errorHandler

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    init(_ id: Account.ID?) {
        self.id = id
    }

    @State
    var primaryTabSelection: Int = 1

    var body: some View {
        FetchableValueView(value: account, canRefresh: false) { [instanceModel, id] in
            if let id {
                return try await instanceModel.service.perform { baseURL, token in
                    MastodonAPI.Accounts.Retrieve(baseURL: baseURL, token: token, id: id)
                }
            }
            else {
                return await instanceModel.signin.account
            }
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
                Text(account.note.safeMastodonAttributedString)
                LabeledContent("Joined") {
                    Text(account.created, style: .date)
                }
                Grid {
                    ForEach(account.fields.indices, id: \.self) { index in
                        GridRow {
                            let field = account.fields[index]
                            Text(field.name)
                            Text(field.value.safeMastodonAttributedString)
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
