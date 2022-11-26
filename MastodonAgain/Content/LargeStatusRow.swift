import AVKit
import Mastodon
import SwiftUI

struct LargeStatusRow: View, Sendable {
    @Binding
    var status: Status

    @Environment(\.openURL)
    var openURL

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            avatar
            VStack(alignment: .leading) {
                header
                content
                footer
            }
        }
        .listRowSeparator(.visible, edges: .bottom)
    }

    @ViewBuilder
    var avatar: some View {
        Avatar(account: status.account, quicklook: false)
            .frame(width: 40, height: 40)
    }

    @ViewBuilder
    var header: some View {
        HStack {
            Text(status.account.name).bold() + Text("@\(status.account.shortUsername)").foregroundColor(.secondary)
            if status.reblog != nil {
                Text("reblogged")
            }
            Spacer()
            if let url = status.url {
                Button {
                    openURL(url)
                } label: {
                    Text(status.created, style: .relative).foregroundColor(.secondary)
                }
                #if os(macOS)
                .buttonStyle(.link)
                #endif
                .fixedSize()
            }
        }
    }

    @ViewBuilder
    var content: some View {
        if let reblog = status.reblog {
            VStack(alignment: .leading) {
                Text(reblog.account.name).bold() + Text("@\(reblog.account.shortUsername)").foregroundColor(.secondary)
                LargeStatusContent(status: reblog)
            }
            .padding(4)
            .background(Color.blue.opacity(0.1).cornerRadius(4))
        }
        else {
            LargeStatusContent(status: status)
        }
    }

    @ViewBuilder
    var footer: some View {
        HStack(alignment: .center, spacing: 32) {
            StatusActions(status: _status)
            HStack(spacing: 8) {
                Text(verbatim: "ID: \(status.id)")
                if let reblog = status.reblog {
                    Text(verbatim: "(Reblogged ID: \(reblog.id))")
                }
                if status.reblogged ?? false {
                    Text("Reblogged")
                }
                if status.sensitive {
                    Text("Sensitive")
                }
                if status.card != nil {
                    Text("Card")
                }
                if status.poll != nil {
                    Text("Card")
                }
                if !status.mediaAttachments.isEmpty {
                    Text("\(status.mediaAttachments.count) attachments")
                }
                if status.bookmarked ?? false {
                    Text("Bookmarked")
                }
                if status.favourited ?? false {
                    Text("Favoured")
                }
                if let language = status.language {
                    Text("\(language)")
                }
            }
            .debuggingInfo()
        }
    }
}

// MARK: -

struct LargeStatusContent<Status>: View where Status: StatusProtocol {
    @EnvironmentObject
    var appModel: AppModel

    let status: Status

    var sensitive: Bool {
        status.sensitive
    }

    var hideContent: Bool {
        sensitive && !allowSensitive && appModel.hideSensitiveContent
    }

    @State
    var allowSensitive = false

    var body: some View {
        VStack(alignment: .leading) {
            if sensitive && appModel.hideSensitiveContent == true {
                HStack {
                    status.spoilerText.nilify().map(Text.init)
                    Toggle("Show Sensitive Content", isOn: $allowSensitive)
                }
                .controlSize(.small)
            }
            VStack(alignment: .leading) {
                Text(status.content.safeMastodonAttributedString).textSelection(.enabled)
                if !status.mediaAttachments.isEmpty {
                    MediaStack(attachments: status.mediaAttachments)
                }
                if let poll = status.poll {
                    Text("Poll: \(String(describing: poll))").debuggingInfo()
                }
                if let card = status.card {
                    CardView(card: card)
                }
            }
            .sensitiveContent(hideContent)
            .frame(maxWidth: .infinity, alignment: .leading)
            //            .overlay {
            //                if sensitive && !allowSensitive {
            //                    Color.red.opacity(1).backgroundStyle(.thickMaterial)
            //                }
            //            }
        }
    }
}
