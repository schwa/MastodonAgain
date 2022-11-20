import Mastodon
import SwiftUI

struct StatusRow: View {
    enum Mode: String, RawRepresentable, CaseIterable, Sendable {
        case small
        case large
    }

    @Binding
    var status: Status

    let mode: Mode

    var body: some View {
        switch mode {
        case .small:
            MiniStatusRow(status: _status)
        case .large:
            LargeStatusRow(status: _status)
        }
    }
}
