import SwiftUI
import Mastodon
import AVKit
import CachedAsyncImage

struct MediaStack: View {
    let attachments: [MediaAttachment]

    var body: some View {
        HStack {
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
        .frame(maxHeight: 180)
    }
}

struct ImageAttachmentView: View {
    let attachment: MediaAttachment

    var body: some View {
        if let url = attachment.previewURL, let smallSize = attachment.meta?.small?.cgSize {
            ContentImage(url: url, size: smallSize, blurhash: attachment.blurHash, accessibilityLabel: Text("TODO"))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        else {
            Text("NO PREVIEW OR NO SIZE").debuggingInfo()
        }
    }
}
