import AVKit
import CachedAsyncImage
import Mastodon
import SwiftUI

// TODO: Sendable view?
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
        VStack {
            HStack(alignment: .top) {
                avatar
                VStack(alignment: .leading) {
                    header
                    content
                    footer
                }
            }
            Divider()
        }
    }

    @ViewBuilder
    var avatar: some View {
        Avatar(account: status.account)
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
        .buttonStyle(ActionButtonStyle())
    }
}

// MARK: -

struct StatusActionButton: View {
    let count: Int?
    let label: String
    let systemName: String
    let isOn: Bool
    let action: @Sendable () async throws -> Void

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var inFlight = false

    init(count: Int? = nil, label: String, systemImage systemName: String, isOn: Bool, action: @Sendable @escaping () async throws -> Void) {
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
                await errorHandler { [action] in
                    try await action()
                }
                // try await Task.sleep(nanoseconds: 500_000)
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

// MARK: -

struct StatusContent<Status>: View where Status: StatusProtocol {
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
                HStack() {
                    status.spoilerText.nilify().map(Text.init)
                    Toggle("Show Sensitive Content", isOn: $allowSensitive)
                }
                .controlSize(.small)
            }
            VStack(alignment: .leading) {
                // TODO: Gross.
                if appModel.useMarkdownContent {
                    (try? status.markdownContent).map { Text($0).textSelection(.enabled) }
                }
                else {
                    (try? status.attributedContent).map { Text($0).textSelection(.enabled) }
                }
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

// MARK: -

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
        modifier(SensitiveContentModifier(sensitive: sensitive))
    }
}

// MARK: -

struct StatusActions: View {
    @Binding
    var status: Status

    @Environment(\.openURL)
    var openURL

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @EnvironmentObject
    var stackModel: StackModel

    @Environment(\.openWindow)
    var openWindow

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var isDebugPopoverPresented = false

    var body: some View {
        infoButton
        replyButton
        reblogButton
        favouriteButton
        bookmarkButton
        shareButton
        moreButton
        debugButton
    }

    @ViewBuilder
    var replyButton: some View {
        Button(systemImage: "arrowshape.turn.up.backward", action: {
            openWindow(value: NewPostWindow.reply(status.id))
        })
    }

    @ViewBuilder
    var infoButton: some View {
        Button(systemImage: "info", action: {
            stackModel.path.append(.status(status.id))
        })
    }

    // TODO: Experiments here to solve Capture of 'self' with non-sendable type 'StatusRow' in a `@Sendable` closure
    @ViewBuilder
    var reblogButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let reblogged = resolvedStatus.reblogged ?? false
        StatusActionButton(count: resolvedStatus.reblogsCount, label: "reblog", systemImage: "arrow.2.squarepath", isOn: reblogged) { [instanceModel, status] in
            await errorHandler {
                // TODO: what status do we get back here?
                _ = try await instanceModel.service.reblog(status: resolvedStatus.id, set: !reblogged)
                // TODO: Because of uncertainty of previous TODO - fetch a fresh status
                let newStatus = try await instanceModel.service.fetchStatus(for: status.id)
                await MainActor.run {
                    self.status = newStatus
                }
            }
        }
    }

    func update(_ status: Status) async {
        await MainActor.run {
            self.status = status
        }
    }

    @ViewBuilder
    var favouriteButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let favourited = resolvedStatus.favourited ?? false
        StatusActionButton(count: resolvedStatus.favouritesCount, label: "Favourite", systemImage: "star", isOn: favourited) { [instanceModel, status] in
            await errorHandler {
                // TODO: what status do we get back here?
                _ = try await instanceModel.service.favorite(status: resolvedStatus.id, set: !favourited)
                // TODO: Because of uncertainty of previous TODO - fetch a fresh status
                let newStatus = try await instanceModel.service.fetchStatus(for: status.id)
                await MainActor.run {
                    self.status = newStatus
                }
            }
        }
    }

    @ViewBuilder
    var bookmarkButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let bookmarked = resolvedStatus.bookmarked ?? false
        StatusActionButton(label: "Bookmark", systemImage: "bookmark", isOn: bookmarked) { [instanceModel, status] in
            await errorHandler {
                // TODO: what status do we get back here?
                _ = try await instanceModel.service.bookmark(status: resolvedStatus.id, set: !bookmarked)
                // TODO: Because of uncertainty of previous TODO - fetch a fresh status
                let newStatus = try await instanceModel.service.fetchStatus(for: status.id)
                await MainActor.run {
                    self.status = newStatus
                }
            }
        }
    }

    @ViewBuilder
    var moreButton: some View {
        Button(systemImage: "ellipsis", action: {})
    }

    @ViewBuilder
    var shareButton: some View {
        let status: any StatusProtocol = status.reblog ?? status
        let url = status.url! // TODO:
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

    @ViewBuilder
    var debugView: some View {
        // https://mastodon.example/api/v1/statuses/:id
        let url = URL(string: "https://\(instanceModel.signin.host)/api/v1/statuses/\(status.id.rawValue)")!
        let request = URLRequest(url: url)
        RequestDebugView(request: request).padding()
    }
}
