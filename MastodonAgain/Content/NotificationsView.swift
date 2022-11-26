import Everything
import Mastodon
import SwiftUI

struct NotificationsView: View {
    var body: some View {
        TabView {
            ForEach(NotificationType.allCases, id: \.self) { type in
                NotificationTypeView(type: type)
                    .tabItem {
                        Text(verbatim: "\(type)")
                    }
            }
        }
    }
}

struct NotificationTypeView: View {
    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @Environment(\.errorHandler)
    var errorHandler

    let type: NotificationType

    @State
    var notifications: [Mastodon.Notification] = []

    var body: some View {
        List(notifications) { notification in
            switch type {
            case .follow:
                AccountRow(account: .constant(notification.account!)) // TODO:
                    .listRowSeparator(.visible, edges: .bottom)
            case .favourite:
                MiniStatusRow(status: .constant(notification.status!))
                    .listRowSeparator(.visible, edges: .bottom)
            case .reblog:
                MiniStatusRow(status: .constant(notification.status!))
                    .listRowSeparator(.visible, edges: .bottom)
            case .mention:
                MiniStatusRow(status: .constant(notification.status!))
                    .listRowSeparator(.visible, edges: .bottom)
            case .poll:
                Text("Poll")
                DebugDescriptionView(notification).debuggingInfo()
                    .listRowSeparator(.visible, edges: .bottom)
            case .followRequest:
                Text("FollowRequest")
                DebugDescriptionView(notification).debuggingInfo()
                    .listRowSeparator(.visible, edges: .bottom)
            }
        }
        .task {
            await errorHandler {
                let notifications = try await instanceModel.service.perform { baseURL, token in
                    MastodonAPI.Notifications.GetAll(baseURL: baseURL, token: token, types: [type])
                }
                await MainActor.run {
                    self.notifications = notifications
                }
            }
        }
    }
}

struct AccountRow: View {
    @Binding
    var account: Account

    @State
    var relationship: Relationship?

    var body: some View {
        VStack {
            HStack {
                Avatar(account: account)
                    .frame(width: 64, height: 64)
                VStack {
                    Text(verbatim: account.name)
                    account.username.map { Text(verbatim: "@\($0)") }
                }
                account.locked ? Text("Locked") : nil
                account.bot ? Text("Bot") : nil
                account.discoverable ?? false ? Text("Discoverable") : nil
                account.group ? Text("Group") : nil
                account.noindex ?? false ? Text("Noindex") : nil
            }
            Text(account.note.safeMastodonAttributedString)
            account.url.map { Text($0, format: .url) }

            LabeledContent("Last Post") {
                account.lastStatusAt.map { Text($0, style: .relative) }
            }
            LabeledContent("Posts") {
                Text(account.statusesCount, format: .number)
            }
            LabeledContent("Followers") {
                Text(account.followersCount, format: .number)
            }
            LabeledContent("Following") {
                Text(account.followingCount, format: .number)
            }
            Grid {
                ForEach(account.fields.indices, id: \.self) { index in
                    GridRow {
                        let field = account.fields[index]
                        Text(field.name).border(Color.black).frame(maxWidth: .infinity, maxHeight: .infinity).border(Color.black)
                        Text(field.value.safeMastodonAttributedString).frame(maxWidth: .infinity, maxHeight: .infinity).border(Color.black)
                    }
                }
            }

            DebugDescriptionView(account.emojis).debuggingInfo()

            HStack {
                AccountActions(account: $account, relationship: $relationship)
                Button("Un/Mute") {
                }
                Button("Un/Block") {
                }
                Button("Note") {
                }
            }

            // DebugDescriptionView(account).debuggingInfo()
        }
    }
}
