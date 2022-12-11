import AVKit
import CachedAsyncImage
import Everything
import Mastodon
import QuickLook
import SwiftUI

struct MediaStack: View {
    let attachments: [MediaAttachment]

    @State
    var quicklookSelection: URL?

    var urls: [URL] {
        attachments.map(\.url)
    }

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
        .quickLookPreview($quicklookSelection, in: urls)
        .onTapGesture {
            // TODO: What if user taps on another image
            quicklookSelection = urls.first
        }
        .accessibilityAddTraits(.isButton)
        .frame(maxHeight: 160)
    }
}

struct ImageAttachmentView: View {
    let attachment: MediaAttachment

    var body: some View {
        if let url = attachment.previewURL, let smallSize = attachment.meta?.small?.cgSize {
            ContentImage(url: url, size: smallSize, blurhash: attachment.blurHash)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(attachment.description ?? "User provided image with no description.")
                .accessibilityHint("Shows info about the image.")
                .overlay(alignment: .topTrailing) {
                    ValueView(value: false) { isPresented in
                        Group {
                            if attachment.description != nil {
                                Button(systemImage: "info.bubble.fill") {
                                    isPresented.wrappedValue = true
                                }
                                .foregroundColor(.accentColor)
                            }
                            else {
                                Button(systemImage: "exclamationmark.triangle.fill") {
                                    isPresented.wrappedValue = true
                                }
                                .foregroundColor(.yellow)
                            }
                        }
                        .padding(4)
                        .buttonStyle(CircleButtonStyle())
                        .accessibilityLabel("Image info")
                        .popover(isPresented: isPresented) {
                            Group {
                                if let description = attachment.description {
                                    Text(description)
                                }
                                else {
                                    Text("User provided image with no description.")
                                }
                            }
                            .padding()
                        }
                    }
                }
        }
        else {
            Text("NO PREVIEW OR NO SIZE").debuggingInfo()
        }
    }
}

struct ContentImage: View {
    let url: URL
    let size: CGSize?
    let blurhash: Blurhash?
    let sensitive: Bool

    @State
    var hover = false

    init(url: URL, size: CGSize? = nil, blurhash: Blurhash? = nil, sensitive: Bool = false) {
        assert(size == nil || size?.width ?? 0 > 0 && size?.height ?? 0 > 0)
        self.url = url
        self.size = size
        self.blurhash = blurhash
        self.sensitive = sensitive
    }

    var body: some View {
        image
    }

    var image: some View {
        CachedAsyncImage(url: url, urlCache: .imageCache) { image in
            image.resizable().scaledToFit()
        }
        placeholder: {
            if let blurhash, let size {
                tryElseLog {
                    try blurhash.image(size: size)
                }
            }
            else {
                LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .overlay {
            if hover {
                Color.clear.redlined()
            }
        }
        /*
                 .overlay(alignment: .bottom) {
                     if hover, let size {
                         VStack {
         //                    Text("\(url, format: .url)").lineLimit(1)
                             Text("\(size.width, format: .number), \(size.height, format: .number)")
                             // , \(size.width / size.height, format: .number):1
                         }
                         .font(.caption2)
                         .padding(2)
                         .background(Capsule().fill(Color.white))
                         .overlay(Capsule().stroke(Color.black))
                         .padding(4)
                     }
                 }
                 .overlay {
                     Color.clear.onHover { value in
                         hover = value
                     }
                 }
                 .id(url)
         */
    }
}
