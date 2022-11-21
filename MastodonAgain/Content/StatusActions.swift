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
        .buttonStyle(TODOButtonStyle())
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
            .buttonStyle(TODOButtonStyle())
    }

    @ViewBuilder
    var shareButton: some View {
        let status: any StatusProtocol = status.reblog ?? status
        let url = status.url! // TODO:
        // TODO: We can't make the ShareLink styled
        ShareLink(item: url, label: { Image(systemName: "square.and.arrow.up") })
//            .buttonStyle(TODOButtonStyle())
    }

    @ViewBuilder
    var debugButton: some View {
        Button(systemImage: "ladybug", action: {
            isDebugPopoverPresented = true
        })
        .popover(isPresented: $isDebugPopoverPresented) {
            debugView
        }
        .buttonStyle(TODOButtonStyle())
    }

    @ViewBuilder
    var debugView: some View {
        // https://mastodon.example/api/v1/statuses/:id
        let url = URL(string: "https://\(instanceModel.signin.host)/api/v1/statuses/\(status.id.rawValue)")!
        let request = URLRequest(url: url)
        RequestDebugView(request: request).padding()
    }
}

// MARK: -

struct StatusActionButton: View {
    let count: Int?
    let label: String
    let systemName: String
    let isOn: Bool
    let action: @Sendable () async throws -> Void

    @Environment(\.errorHandler)
    var errorHandler

    @Environment(\.isSelected)
    var isSelected

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
        Button(title: label, systemImage: systemName) {
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
        }
        .buttonStyle(TODOButtonStyle(isHighlighted: isOn, count: count, isInProgress: inFlight))
    }
}

// MARK: -

struct TODOButtonStyle: ButtonStyle {
    @Environment(\.isSelected)
    var isSelected

    let isHighlighted: Bool
    let count: Int?
    let isInProgress: Bool

    init(isHighlighted: Bool = false, count: Int? = nil, isInProgress: Bool = false) {
        self.isHighlighted = isHighlighted
        self.count = count
        self.isInProgress = isInProgress
    }

    func makeBody(configuration: Configuration) -> some View {
        // TODO: Make leading?
        ZStack {
            ProgressView().controlSize(.small)
                .hidden(!isInProgress)
            configuration.label
                .labelStyle(_LabelStyle(isSelected: isSelected, isHighlighted: isHighlighted, count: count))
                .padding(2)
                .background {
                    if configuration.isPressed {
                        Color.gray.opacity(0.5).cornerRadius(2)
                    }
                }
                .hidden(isInProgress)
        }
    }

    struct _LabelStyle: LabelStyle {
        let isSelected: Bool
        let isHighlighted: Bool
        let count: Int?

        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 1) {
                configuration.icon
                    .foregroundColor(isHighlighted ? .accentColor : nil)
                Text(count ?? 0, format: .number)
                    .font(.caption)
                    .monospacedDigit()
            }
        }
    }
}

struct TODOButtonPreview: PreviewProvider {
    static var previews: some View {
        VStack {
            Button(title: "Gear", systemImage: "gear", action: {})
                .buttonStyle(TODOButtonStyle(isHighlighted: true, count: 5, isInProgress: true))

            Button(title: "Gear", systemImage: "gear", action: {})
                .buttonStyle(TODOButtonStyle(isHighlighted: true, count: 5, isInProgress: false))
        }
    }
}
