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
