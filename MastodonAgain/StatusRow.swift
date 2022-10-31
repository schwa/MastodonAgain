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
            CardView(card: card)
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

struct ContentImage: View {
    let url: URL
    let size: CGSize?
    let blurhash: Blurhash?
    let sensitive: Bool
    let accessibilityLabel: Text?

    @State
    var hover = false

    init(url: URL, size: CGSize? = nil, blurhash: Blurhash? = nil, sensitive: Bool = false, accessibilityLabel: Text? = nil) {
        self.url = url
        self.size = size
        self.blurhash = blurhash
        self.sensitive = sensitive
        self.accessibilityLabel = accessibilityLabel
    }

    var body: some View {
        image
    }

    var image: some View {
        CachedAsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        }
        placeholder: {
            if let blurhash, let size {
                blurhash.image(size: size)
            }
            else {
                LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .onHover { value in
            hover = value
        }
        .redlined(hover)
//        .overlay() {
//            if hover {
//                VStack {
//                    Text("\(url, format: .url)").lineLimit(1)
//                    if let size {
//                        Text("\(size.width, format: .number), \(size.height, format: .number)")
//                    }
//                }
//                .font(.caption2)
//                .padding()
//                .background(Capsule().fill(Color.white))
//            }
//        }
    }
}

extension Card {
    var size: CGSize? {
        guard let width = width, let height = height else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}

struct CardView: View {
    let card: Card

    var body: some View {
        switch card.type {
        case .link:
            Link(destination: card.url) {
                HStack {
                    if let image = card.image {
                        ContentImage(url: image, size: card.size, blurhash: card.blurhash, accessibilityLabel: Text("TODO"))
                        .frame(maxHeight: 80)
                        .border(Color.purple)
                    }
                    if let description = card.title ?? card.description {
                        Label("\(description) (\(card.url.absoluteString))", systemImage: "link").symbolVariant(.circle)
                    }
                    else {
                        Label(card.url.absoluteString, systemImage: "link").symbolVariant(.circle)
                    }
                }
            }
            .border(Color.red)
//            if let width = card.width, let height = card.height, let blurHash = card.blurhash {
//                Image(blurHash: blurHash, size: [width, height])
//            }
// {"url":"https://twitodon.com/","title":"Twitodon - Find your Twitter friends on Mastodon","description":"","type":"link","author_name":"","author_url":"","provider_name":"","provider_url":"","html":"","width":0,"height":0,"image":null,"embed_url":"","blurhash":null}

//            "card" : {
//                "author_name" : "",
//                "author_url" : "",
//                "blurhash" : "U009m+ayWBaxROj[ofj]ozayayayayj[f6j[",
//                "description" : "“Riven.\n\nOfficially in development at Cyan.\n\nFAQ: https://t.co/6YeeamoJaq”",
//                "embed_url" : "",
//                "height" : 225,
//                "html" : "",
//                "image" : "https://files.mastodon.social/cache/preview_cards/images/046/839/502/original/d99d01f5953824cf.jpeg",
//                "provider_name" : "Twitter",
//                "provider_url" : "",
//                "title" : "Cyan Inc. on Twitter",
//                "type" : "link",
//                "url" : "https://twitter.com/cyanworlds/status/1587065601339424770",
//                "width" : 400
//            },

        case .photo:
            Text("Photo Card: \(String(describing: card))").debuggingInfo()
        case .video:
            Text("Video Card: \(String(describing: card))").debuggingInfo()
        case .rich:
            Text("Video Card: \(String(describing: card))").debuggingInfo()
        }
    }
}
