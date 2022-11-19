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
            switch notification.type {
            case .favourite:

                Text(verbatim: "\(notification.type)")

                MiniStatusRow(status: .constant(notification.status!))

            default:
                Text(verbatim: "\(notification.type)")
            }


        }
        .task {
            await errorHandler {
                let notifications = try await instanceModel.service.perform(type: [Mastodon.Notification].self) { baseURL, token in
                    MastodonAPI.Notifications.GetAll(baseURL: baseURL, token: token, types: [type])
                }
                await MainActor.run {
                    self.notifications = notifications
                }
            }
        }
    }
}
