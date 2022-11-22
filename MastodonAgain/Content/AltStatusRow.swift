import AVKit
import CachedAsyncImage
import Mastodon
import SwiftUI

let dateFormatter = {
    var formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter
}()


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
                content
                if hover {
                    footer
                }
            }
        }
        .padding(.vertical, 2.0)
        .listRowSeparator(.visible, edges: .bottom)
        .onHover { hover in
            if self.hover != hover {
//                withAnimation(.easeIn(duration: 0.5)) {
                    self.hover = hover
//                }
            }
        }
    }

    @ViewBuilder
    var avatar: some View {
        Avatar(account: originalAccount)
            .frame(width: 40, height: 40)
    }

    @ViewBuilder
    var label: some View {
        HStack(spacing: 0) {
            AccountLabel(originalAccount)
            if let _ = status.reblog {
                Text(" (via ")
                AccountLabel(status.account)
                Text(")")
            }
        }
    }
    
    @ViewBuilder
    var header: some View {
        HStack {
            label
                .lineLimit(1)
                .truncationMode(.tail)
            if let url = status.url {
                Spacer()
                Button {
                    openURL(url)
                } label: {
                    let formatted = appModel.relativeDate(status.created)
                    Text(formatted)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
                #if os(macOS)
                .buttonStyle(.link)
                #endif
                .fixedSize()
            }
        }
        .padding(.bottom, 2.0)
    }

    @ViewBuilder
    var content: some View {
        if let reblog = status.reblog {
            StatusContent(status: reblog)
        } else {
            StatusContent(status: status)
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
