import Mastodon
import SwiftUI
import AVKit
import CachedAsyncImage

struct StatusRow: View {
    let status: Status

    @Environment(\.openURL)
    var openURL

    @EnvironmentObject
    var appModel: AppModel


    var body: some View {
        HStack(alignment: .top) {
            Avatar(url: status.account.avatar)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading) {
                HStack {
                    if !status.account.displayName.isEmpty {
                        Text("\(status.account.displayName)").bold().fixedSize()
                    }
                    Text("@\(status.account.acct)")
                        .foregroundColor(.secondary).fixedSize()
                    Spacer()

                    Button {
                        openURL(status.url!)
                    } label: {
                        Text(status.created, style: .relative).foregroundColor(.secondary)
                    }
                    .buttonStyle(.link)
                    .fixedSize()
                }
                Text(status.attributedContent)
                    .textSelection(.enabled)
                if status.mediaAttachments.count > 0 {
                    MediaStack(attachments: status.mediaAttachments)
                }
                HStack(spacing: 32) {
                    Button(systemImage: "arrowshape.turn.up.backward", action: {})
                    Button(systemImage: "arrowshape.bounce.right", action: {})
                    Button(systemImage: "star", action: {
                        Task {
                            try await appModel.service.favorite(status: status)
                        }
                    })
                    Button(systemImage: "bookmark", action: {})
                    Button(systemImage: "square.and.arrow.up", action: {})
                    Button(systemImage: "ellipsis", action: {})
                }
                .buttonStyle(.borderless)
            }
        }

    }
}

struct MediaStack: View {

    let attachments: [MediaAttachment]

    var body: some View {
        LazyHStack {
            ForEach(attachments) { attachment in
                switch attachment.type {
                case .image, .gifv:
                    ImageAttachmentView(attachment: attachment)
                case .video:
                    VideoPlayer(player: AVPlayer(url: attachment.url))
                case .audio:
                    VideoPlayer(player: AVPlayer(url: attachment.url))
                case .unknown:
                    Text("Unknown attachment")
                }
            }

        }

    }
}


struct ImageAttachmentView: View {
    let attachment: MediaAttachment

    var body: some View {
        if let smallSize = attachment.meta?.small?.cgSize {
            CachedAsyncImage(url: attachment.previewURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                if let blurHash = attachment.blurHash, let image = Image(blurHash: blurHash, size: smallSize) {
                    image
                }
                else {
                    LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(width: smallSize.width, height: smallSize.height, alignment: .center)
            .redlined()
        }
        else {
            Text("NO SIZE").foregroundColor(.red)
        }


    }
}

