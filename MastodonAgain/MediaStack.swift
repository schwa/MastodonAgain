import SwiftUI
import Mastodon
import AVKit
import CachedAsyncImage

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
                image.resizable().scaledToFill()
                    .accessibilityLabel("TODO (Loaded)")
            }
            placeholder: {
                Group {
                    if let blurHash = attachment.blurHash, let image = Image(blurHash: blurHash, size: smallSize) {
                        image
                    }
                    else {
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .accessibilityLabel("TODO (Loading)")
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
