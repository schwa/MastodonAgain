import AVKit
import CachedAsyncImage
import Mastodon
import SwiftUI

// TODO: Sendable view?
struct AltStatusRow: View, Sendable {
    @Binding
    var status: Status

    @Environment(\.openURL)
    var openURL

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @State
    var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            avatar
            VStack(alignment: .leading) {
                header
                    .padding(.bottom, 2.0)
                content
                if hover {
                    footer
                }
            }
        }
        .padding(.vertical, 2.0)
        .listRowSeparator(.visible, edges: .bottom)
        .onHover { hover in
            withAnimation {
                self.hover = hover
            }
        }
    }

    @ViewBuilder
    var avatar: some View {
        Avatar(account: originalAccount)
            .frame(width: 40, height: 40)
    }

    @ViewBuilder
    var header: some View {
        HStack {
            Text(originalAccount, showHandle: false)
            if let _ = status.reblog {
                Text("(via ") +
                Text(status.account, showHandle: false) +
                Text(")")
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
            StatusContent(status: reblog, quotedBy: status)
        } else {
            StatusContent(status: status, quotedBy: nil)
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
    
    var originalAccount: Account {
        status.reblog?.account ?? status.account
    }
}
