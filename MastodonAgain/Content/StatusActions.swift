import Everything
import Mastodon
import SwiftUI

struct StatusActions: View {
    @Binding
    var status: Status

    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @EnvironmentObject
    var stackModel: StackModel

    @Environment(\.openWindow)
    var openWindow

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var isDebugPopoverPresented = false

    var body: some View {
        Group {
            infoButton
            replyButton
            reblogButton
            favouriteButton
            bookmarkButton
            shareButton
            moreButton
            debugButton
        }
        .buttonStyle(ActionButtonStyle())
    }

    // MARK: -

    @ViewBuilder
    var replyButton: some View {
        Button(systemImage: "arrowshape.turn.up.backward", action: {
            openWindow(value: NewPostWindow.reply(status.id))
        })
    }

    @ViewBuilder
    var infoButton: some View {
        Button(systemImage: "info", action: {
            stackModel.path.append(.status(status.id))
        })
    }

    @ViewBuilder
    var reblogButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let reblogged = resolvedStatus.reblogged ?? false
        ValueView(value: false) { inflight in
            Button(title: "reblog", systemImage: "arrow.2.squarepath") {
                inflight.wrappedValue = true
                await errorHandler {
                    defer {
                        inflight.wrappedValue = false
                    }
                    _ = try await instanceModel.service.reblog(status: resolvedStatus.id, set: !reblogged)
                    try await updateStatus()
                }
            }
            .altBadge(resolvedStatus.reblogsCount)
            .highlighted(value: reblogged)
            .inflight(value: inflight.wrappedValue)
        }
    }

    @ViewBuilder
    var favouriteButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let favourited = resolvedStatus.favourited ?? false

        ValueView(value: false) { inflight in
            Button(title: "Favourite", systemImage: "star") {
                inflight.wrappedValue = true
                await errorHandler {
                    defer {
                        inflight.wrappedValue = false
                    }
                    _ = try await instanceModel.service.favorite(status: resolvedStatus.id, set: !favourited)
                    try await updateStatus()
                }
            }
            .altBadge(resolvedStatus.favouritesCount)
            .highlighted(value: favourited)
            .inflight(value: inflight.wrappedValue)
        }
    }

    @ViewBuilder
    var bookmarkButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let bookmarked = resolvedStatus.bookmarked ?? false
        ValueView(value: false) { inflight in
            Button(title: "Bookmark", systemImage: "bookmark") {
                inflight.wrappedValue = true
                await errorHandler {
                    defer {
                        inflight.wrappedValue = false
                    }
                    _ = try await instanceModel.service.bookmark(status: resolvedStatus.id, set: !bookmarked)
                    try await updateStatus()
                }
            }
            .highlighted(value: bookmarked)
            .inflight(value: inflight.wrappedValue)
        }
    }

    @ViewBuilder
    var moreButton: some View {
        Button(systemImage: "ellipsis", action: {})
    }

    @ViewBuilder
    var shareButton: some View {
        let status: any StatusProtocol = status.reblog ?? status
        if let url = status.url {
            ShareLink(item: url, label: { Image(systemName: "square.and.arrow.up") })
        }
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

    @ViewBuilder
    var debugView: some View {
        // https://mastodon.example/api/v1/statuses/:id
        let url = URL(string: "https://\(instanceModel.signin.host)/api/v1/statuses/\(status.id.rawValue)")!
        let request = URLRequest(url: url)
        RequestDebugView(request: request).padding()
    }

    // MARK: -

    func updateStatus() async throws {
        let newStatus = try await instanceModel.service.fetchStatus(for: status.id)
        await MainActor.run {
            self.status = newStatus
        }
    }
}
