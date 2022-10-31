import AVKit
import CachedAsyncImage
import Mastodon
import SwiftUI

struct StatusRow: View {
    @Binding
    var status: Status

    @Environment(\.openURL)
    var openURL

    @EnvironmentObject
    var appModel: AppModel

    @Environment(\.openWindow)
    var openWindow

    var body: some View {
        HStack(alignment: .top) {
            avatar
            VStack(alignment: .leading) {
                header
                content
                footer
            }
        }
    }

    @State
    var isDebugPopoverPresented = false

    @ViewBuilder
    var avatar: some View {
        Avatar(url: status.account.avatar)
            .frame(width: 40, height: 40)
    }

    @ViewBuilder
    var header: some View {
        HStack {
            AccountName(account: status.account)
            Spacer()
            Button {
                openURL(status.url!)
            } label: {
                Text(status.created, style: .relative).foregroundColor(.secondary)
            }
#if os(macOS)
            .buttonStyle(.link)
#endif
            .fixedSize()
        }    }

    @ViewBuilder
    var content: some View {
        if let reblog = status.reblog {
            VStack(alignment: .leading) {
                AccountName(account: reblog.account)
                Text(reblog.attributedContent)
                    .textSelection(.enabled)
            }
            .background(Color.blue.opacity(0.1))
        }
        else {
            Text(status.attributedContent)
                .textSelection(.enabled)
            if !status.mediaAttachments.isEmpty {
                MediaStack(attachments: status.mediaAttachments)
            }
        }
        if let poll = status.poll {
            Text("Poll: \(String(describing: poll))").debuggingInfo()
        }
        if let card = status.card {
            Text("Card: \(String(describing: card))").debuggingInfo()
        }
    }

    @ViewBuilder
    var footer: some View {
        HStack(alignment: .center, spacing: 32) {
            replyButton
            reblogButton
            favouriteButton
            bookmarkButton
            shareButton
            moreButton
            debugButton

            HStack {
                Text(verbatim: "ID: \(status.id)")
                if let reblog = status.reblog {
                    Text(verbatim: "(Reblogged ID: \(reblog.id))")
                }
            }
            .debuggingInfo()
        }
        .buttonStyle(ActionButtonStyle())
    }

    @ViewBuilder
    var debugView: some View {
        // https://mastodon.example/api/v1/statuses/:id
        let url = URL(string: "https://\(appModel.host)/api/v1/statuses/\(status.id.rawValue)")!
        let request = URLRequest(url: url)
        RequestDebugView(request: request).padding()
    }

    @ViewBuilder
    var replyButton: some View {
        Button(systemImage: "arrowshape.turn.up.backward", action: {
            openWindow(value: NewPost.reply(status.id))
        })
    }

    @ViewBuilder
    var reblogButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        actionButton(count: resolvedStatus.reblogsCount, label: "reblog", systemImage: "arrow.2.squarepath", selected: resolvedStatus.reblogged ?? false) {
            // TODO: what status do we get back here?
            try! await appModel.service.reblog(status: resolvedStatus.id)
            // TODO: Because of uncertainty of previous TODO - fetch a fresh status
            status = try! await appModel.service.fetchStatus(for: self.status.id)
        }
    }

    @ViewBuilder
    var favouriteButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        actionButton(count: resolvedStatus.favouritesCount, label: "Favourite", systemImage: "star", selected: resolvedStatus.favourited ?? false) {
            // TODO: what status do we get back here?
            try! await appModel.service.favorite(status: resolvedStatus.id)
            // TODO: Because of uncertainty of previous TODO - fetch a fresh status
            status = try! await appModel.service.fetchStatus(for: self.status.id)
        }
    }

    @ViewBuilder
    var bookmarkButton: some View {
        Button(systemImage: "bookmark", action: {})
    }

    @ViewBuilder
    var moreButton: some View {
        Button(systemImage: "ellipsis", action: {})
    }

    @ViewBuilder
    var shareButton: some View {
        let status: any StatusProtocol = status.reblog ?? status
        let url = status.url! // TODO
        ShareLink(item: url, label: { Image(systemName: "square.and.arrow.up") })
    }

    @ViewBuilder
    var debugButton: some View {
        Button(systemImage: "ladybug", action: {
            isDebugPopoverPresented = true
        })
        .popover(isPresented: $isDebugPopoverPresented) {
            debugView
        }
    }

    func actionButton(count: Int, label: String, systemImage systemName: String, selected: Bool, action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            let image = Image(systemName: systemName)
                .symbolVariant(selected ? .fill : .none)
                .foregroundColor(selected ? .accentColor : nil)
            // swiftlint:disable:next empty_count
            if count > 0 {
                Label {
                    Text("\(count, format: .number)")
                } icon: {
                    image
                }
            }
            else {
                image
            }
        }
    }
}

struct AccountName: View {
    let account: Account

    var body: some View {
        // TODO: Dog's dinner.
        var text = Text("")
        if !account.displayName.isEmpty {
            // swiftlint:disable shorthand_operator
            text = text + Text("\(account.displayName)").bold()
        }
        text = text + Text(" ") + Text("@\(account.acct)")
                .foregroundColor(.secondary)
        return text
    }
}
