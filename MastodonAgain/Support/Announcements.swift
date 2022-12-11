import AsyncAlgorithms
import SwiftUI

actor Announcer {
    var announcements = AsyncChannel<Announcement>()

    func send(_ announcement: Announcement) async {
        await announcements.send(announcement)
    }
}

struct Announcement: Sendable {
    var heading: String?
    var description: String?

    var callback: @Sendable () -> Void

    init(heading: String? = nil, description: String? = nil, callback: @escaping @Sendable () -> Void) {
        self.heading = heading
        self.description = description
        self.callback = callback
    }
}

struct AnnouncerKey: EnvironmentKey {
    static var defaultValue = Announcer()
}

extension EnvironmentValues {
    var announcer: Announcer {
        get {
            self[AnnouncerKey.self]
        }
        set {
            self[AnnouncerKey.self] = newValue
        }
    }
}

struct AnnouncerModifier: ViewModifier {
    @State
    var currentAnnouncement: Announcement?

    @Environment(\.announcer)
    var announcer

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                currentAnnouncement.map {
                    AnnouncementView(announcement: $0)
                        .padding()
                }
            }
            .task {
                do {
                    for await announcement in await announcer.announcements {
                        await MainActor.run {
                            withAnimation {
                                self.currentAnnouncement = announcement
                            }
                        }
                        try await Task.sleep(for: .seconds(10))
                        await MainActor.run {
                            withAnimation {
                                self.currentAnnouncement = nil
                            }
                        }
                    }
                }
                catch {
                }
            }
    }
}

extension View {
    func announcer() -> some View {
        modifier(AnnouncerModifier())
    }
}

struct AnnouncementView: View {
    let announcement: Announcement

    let style = BasicAnnouncementStyle()

    var body: some View {
        style.makeBody(configuration: .init(announcement: announcement))
            .overlay(alignment: .topLeading) {
                Button(title: "Close", systemImage: "xmark") {
                }
                .buttonStyle(CircleButtonStyle())
            }
    }
}

struct AnnouncementStyleConfiguration {
    let announcement: Announcement
}

protocol AnnouncementStyle {
    associatedtype Body: View
    typealias Configuration = AnnouncementStyleConfiguration

    @ViewBuilder
    func makeBody(configuration: Configuration) -> Body
}

struct BasicAnnouncementStyle: AnnouncementStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.announcement.heading.map { Text($0) }
            configuration.announcement.description.map { Text($0) }
        }
        .padding()
        .background(Color.blue.opacity(0.8).cornerRadius(8))
    }
}

struct SillyAnnouncementStyle: AnnouncementStyle {
    @State
    var n: Double = 0

    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.announcement.heading.map { Text($0) }
            configuration.announcement.description.map { Text($0) }
        }
        .padding()
        .background(Color.orange.opacity(0.8).cornerRadius(8))
        .scaleEffect(CGSize(1 + n * 0.25, 1 + n * 0.25))
        .rotationEffect(.degrees((n - 0.5) * 20))
        .onAppear {
            withAnimation(.linear.repeatForever(autoreverses: true)) {
                n += 1
            }
        }
    }
}

struct CircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(4)
            .background(Circle().fill(Color.white))
            .labelStyle(_Label())
    }

    // TODO: Make IconOnlyLabelStyle
    struct _Label: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.icon
        }
    }
}
