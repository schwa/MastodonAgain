import Everything
import Foundation
import Mastodon
import SwiftUI

struct MiniStatusRow: View, Sendable {
    @Binding
    var status: Status

    @Environment(\.openURL)
    var openURL

    @EnvironmentObject
    var appModel: AppModel

    @Environment(\.openWindow)
    var openWindow

    @State
    var hover = false

    var body: some View {
        HStack(alignment: .center) {
            if let reblog = status.reblog {
                HStack(spacing: 2) {
                    Avatar(account: status.account).frame(width: 20, height: 20)
                    Image(systemName: "arrow.counterclockwise.circle").controlSize(.small)
                    Avatar(account: reblog.account).frame(width: 20, height: 20)
                }
                Text(reblog.account.displayName).bold()
                Text(reblog.attributedContent).padding(2).background(Color.blue.opacity(0.1)).lineLimit(1)
            }
            else {
                Avatar(account: status.account).frame(width: 20, height: 20)

                Text(status.account.displayName).bold()
                Text(status.attributedContent).lineLimit(1)
            }
            if !status.mediaAttachments.isEmpty || (status.reblog?.mediaAttachments.isEmpty ?? false) {
                Image(systemName: "photo")
                    .badge(status.mediaAttachments.count + (status.reblog?.mediaAttachments.count ?? 0)).fixedSize()
            }
            Spacer()
            if hover {
                StatusActions(status: _status)
                    .buttonStyle(ActionButtonStyle())
            }
        }
        .onHover { hover in
            self.hover = hover
        }
    }
}

extension Collection where Element == Text {
    func joined(separator: Text) -> Text {
        return reduce(Text("")) { partialResult, element in
            return partialResult + separator + element
        }
    }
}
