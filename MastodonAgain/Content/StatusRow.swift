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
            #if os(iOS)
            NarrowStatusRow(status: _status)
            #else
            LargeStatusRow(status: _status)
            #endif
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
