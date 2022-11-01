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
            Text(status.account)
            if status.reblog != nil {
                Text("reblogged")
            }
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
        }
    }

    @ViewBuilder
    var content: some View {
        if let reblog = status.reblog {
            VStack(alignment: .leading) {
                Text(reblog.account)
                StatusContent(status: reblog)
            }
            .padding(4)
            .background(Color.blue.opacity(0.1).cornerRadius(4))
        }
        else {
            StatusContent(status: status)
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
        .buttonStyle(ActionButtonStyle())
    }

    @ViewBuilder
    var debugView: some View {
        // https://mastodon.example/api/v1/statuses/:id
        let url = URL(string: "https://\(appModel.instance.host)/api/v1/statuses/\(status.id.rawValue)")!
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
        let reblogged = resolvedStatus.reblogged ?? false
        StatusActionButton(count: resolvedStatus.reblogsCount, label: "reblog", systemImage: "arrow.2.squarepath", isOn: reblogged) {
            // TODO: what status do we get back here?
            try! await appModel.service.reblog(status: resolvedStatus.id, set: !reblogged)
            // TODO: Because of uncertainty of previous TODO - fetch a fresh status
            status = try! await appModel.service.fetchStatus(for: self.status.id)
        }
    }

    @ViewBuilder
    var favouriteButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let favourited = resolvedStatus.favourited ?? false
        StatusActionButton(count: resolvedStatus.favouritesCount, label: "Favourite", systemImage: "star", isOn: favourited) {
            // TODO: what status do we get back here?
            try! await appModel.service.favorite(status: resolvedStatus.id, set: !favourited)
            // TODO: Because of uncertainty of previous TODO - fetch a fresh status
            status = try! await appModel.service.fetchStatus(for: self.status.id)
        }
    }

    @ViewBuilder
    var bookmarkButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let bookmarked = resolvedStatus.bookmarked ?? false
        StatusActionButton(label: "Bookmark", systemImage: "bookmark", isOn: bookmarked) {
            // TODO: what status do we get back here?
            try! await appModel.service.bookmark(status: resolvedStatus.id, set: !bookmarked)
            // TODO: Because of uncertainty of previous TODO - fetch a fresh status
            status = try! await appModel.service.fetchStatus(for: self.status.id)
        }
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
}

struct StatusActionButton: View {
    let count: Int?
    let label: String
    let systemName: String
    let isOn: Bool
    let action: () async throws -> Void

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var inFlight = false

    init(count: Int? = nil, label: String, systemImage systemName: String, isOn: Bool, action: @escaping () async throws -> Void) {
        self.count = count
        self.label = label
        self.systemName = systemName
        self.isOn = isOn
        self.action = action
    }

    var body: some View {
        Button {
            guard inFlight == false else {
                appLogger?.debug("Task for \(label) is already in flight, dropping.")
                return
            }
            Task {
                inFlight = true
                await errorHandler.handle {
                    try await action()
                }
                await try Task.sleep(nanoseconds: 500_000)
                inFlight = false
            }
        } label: {
            let image = Image(systemName: systemName)
                .symbolVariant(isOn ? .fill : .none)
                .foregroundColor(isOn ? .accentColor : nil)
            // swiftlint:disable:next empty_count
            if let count, count > 0 {
                Label {
                    Text("\(count, format: .number)")
                } icon: {
                    image
                }
            }
            else {
                if inFlight {
                    ProgressView().controlSize(.small)
                }
                else {
                    image
                }
            }
        }
    }
}

extension Text {
    init(_ account: Account) {
        var text = Text("")
        if !account.displayName.isEmpty {
            // swiftlint:disable shorthand_operator
            text = text + Text("\(account.displayName)").bold()
        }
        self = text + Text(" ") + Text("@\(account.acct)")
                .foregroundColor(.secondary)
    }
}

struct StatusContent <Status>: View where Status: StatusProtocol {
    let status: Status

    @AppStorage("hideSensitiveContent")
    var hideSensitiveContent = false

    var sensitive: Bool {
        return status.sensitive
    }

    var hideContent: Bool {
        sensitive && !allowSensitive && hideSensitiveContent
    }

    @State
    var allowSensitive = false

    @AppStorage("useMarkdownContent")
    var useMarkdownContent = false

    var body: some View {
        VStack(alignment: .leading) {
            if sensitive && hideSensitiveContent == true {
                HStack() {
                    status.spoilerText.nilify().map(Text.init)
                    Toggle("Show Sensitive Content", isOn: $allowSensitive)
                }
                .controlSize(.small)
            }
            VStack(alignment: .leading) {
                Text(useMarkdownContent ? status.markdownContent : status.attributedContent)
                    .textSelection(.enabled)
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

struct SensitiveContentModifier: ViewModifier {
    let sensitive: Bool

    func body(content: Content) -> some View {
        if sensitive {
            content
                .blur(radius: 20)
                .clipped()
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red))
        }
        else {
            content
        }
    }
}

extension View {
    func sensitiveContent(_ sensitive: Bool) -> some View {
        return self.modifier(SensitiveContentModifier(sensitive: sensitive))
    }
}

extension Collection {
    func nilify() -> Self? {
        if isEmpty {
            return nil
        }
        else {
            return self
        }
    }
}
