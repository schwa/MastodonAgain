import Mastodon
import SwiftUI

struct StatusActions: View {
    @Binding
    var status: Status

    @Environment(\.openURL)
    var openURL

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
        infoButton
        replyButton
        reblogButton
        favouriteButton
        bookmarkButton
        shareButton
        moreButton
        debugButton
    }

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

    // TODO: Experiments here to solve Capture of 'self' with non-sendable type 'StatusRow' in a `@Sendable` closure
    @ViewBuilder
    var reblogButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let reblogged = resolvedStatus.reblogged ?? false
        StatusActionButton(count: resolvedStatus.reblogsCount, label: "reblog", systemImage: "arrow.2.squarepath", isOn: reblogged) { [instanceModel, status] in
            await errorHandler {
                // TODO: what status do we get back here?
                _ = try await instanceModel.service.reblog(status: resolvedStatus.id, set: !reblogged)
                // TODO: Because of uncertainty of previous TODO - fetch a fresh status
                let newStatus = try await instanceModel.service.fetchStatus(for: status.id)
                await MainActor.run {
                    self.status = newStatus
                }
            }
        }
    }

    func update(_ status: Status) async {
        await MainActor.run {
            self.status = status
        }
    }

    @ViewBuilder
    var favouriteButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let favourited = resolvedStatus.favourited ?? false
        StatusActionButton(count: resolvedStatus.favouritesCount, label: "Favourite", systemImage: "star", isOn: favourited) { [instanceModel, status] in
            await errorHandler {
                // TODO: what status do we get back here?
                _ = try await instanceModel.service.favorite(status: resolvedStatus.id, set: !favourited)
                // TODO: Because of uncertainty of previous TODO - fetch a fresh status
                let newStatus = try await instanceModel.service.fetchStatus(for: status.id)
                await MainActor.run {
                    self.status = newStatus
                }
            }
        }
    }

    @ViewBuilder
    var bookmarkButton: some View {
        let resolvedStatus: any StatusProtocol = status.reblog ?? status
        let bookmarked = resolvedStatus.bookmarked ?? false
        StatusActionButton(label: "Bookmark", systemImage: "bookmark", isOn: bookmarked) { [instanceModel, status] in
            await errorHandler {
                // TODO: what status do we get back here?
                _ = try await instanceModel.service.bookmark(status: resolvedStatus.id, set: !bookmarked)
                // TODO: Because of uncertainty of previous TODO - fetch a fresh status
                let newStatus = try await instanceModel.service.fetchStatus(for: status.id)
                await MainActor.run {
                    self.status = newStatus
                }
            }
        }
    }

    @ViewBuilder
    var moreButton: some View {
        Button(systemImage: "ellipsis", action: {})
    }

    @ViewBuilder
    var shareButton: some View {
        let status: any StatusProtocol = status.reblog ?? status
        let url = status.url! // TODO:
        ShareLink(item: url, label: { Image(systemName: "square.and.arrow.up") })
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
}

struct StatusActionButton: View {
    let count: Int?
    let label: String
    let systemName: String
    let isOn: Bool
    let action: @Sendable () async throws -> Void

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var inFlight = false

    init(count: Int? = nil, label: String, systemImage systemName: String, isOn: Bool, action: @Sendable @escaping () async throws -> Void) {
        self.count = count
        self.label = label
        self.systemName = systemName
        self.isOn = isOn
        self.action = action
    }

    var body: some View {
        Button {
            guard inFlight == false else {
                appLogger?.debug("Task for \(label) is already in flight, dropping.")
                return
            }
            Task {
                inFlight = true
                await errorHandler { [action] in
                    try await action()
                }
                inFlight = false
            }
        } label: {
            let image = Image(systemName: systemName)
                .symbolVariant(isOn ? .fill : .none)
                .foregroundColor(isOn ? .accentColor : nil)
            // swiftlint:disable:next empty_count
            if let count, count > 0 {
                Label {
                    Text("\(count, format: .number)")
                } icon: {
                    image
                }
            }
            else {
                if inFlight {
                    ProgressView().controlSize(.small)
                }
                else {
                    image
                }
            }
        }
    }
}

// MARK:
