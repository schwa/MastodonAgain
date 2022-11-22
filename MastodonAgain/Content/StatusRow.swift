import Mastodon
import SwiftUI

struct StatusRow: View {
    enum Mode: String, RawRepresentable, CaseIterable, Sendable {
        case mini
        case large
    }

    @Binding
    var status: Status

    let mode: Mode

    var body: some View {
        switch mode {
        case .mini:
            MiniStatusRow(status: _status)
        case .large:
            LargeStatusRow(status: _status)
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
