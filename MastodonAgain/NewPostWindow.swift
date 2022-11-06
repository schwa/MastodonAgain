import Foundation
import SwiftUI
import Mastodon
import AsyncAlgorithms

extension NSItemProvider: @unchecked Sendable {
}

enum NewPostWindow: Codable, Hashable {
    case empty
    case reply(Status.ID) // TODO: Make full status?
}

struct NewPostView: View {
    @EnvironmentObject
    var appModel: AppModel

    @Binding
    var open: NewPostWindow?

    @State
    var newPost: NewPost

    @State
    var images: [Resource<Image>] = []

    @State
    var inReplyTo: Status?

    @State
    var isTargeted = false

    @Environment(\.errorHandler)
    var errorHandler

    init(open: Binding<NewPostWindow?>) {
        self._open = open
        self._newPost = State(initialValue: NewPost(status: "", sensitive: false, spoiler: "", visibility: .public, language: Locale.current.topLevelIdentifier))
    }

    var body: some View {
        VStack {
            VStack {
                DebugDescriptionView(newPost)
            }
            .debuggingInfo()
            if let inReplyTo {
                Text("Replying to \(inReplyTo.account.acct)") // TODO: use full name
            }
            HStack {
                TextEditor(text: $newPost.status)
                ForEach(images, id: \.url) { image in
                    image.content.resizable().scaledToFit()
                    .frame(maxWidth: 80, maxHeight: 80, alignment: .trailing)
                }
            }
            if newPost.sensitive {
                TextField("Content Warning", text: $newPost.spoiler.unwrappingRebound(default: { "" }))
            }
            HStack {
                footer
            }
        }
        .padding()
        .overlay {
            if isTargeted {
                Rectangle().stroke(Color.accentColor, lineWidth: 8)
            }
        }
        .task {
            if case let .reply(id) = open {
                inReplyTo = await appModel.service.status(for: id)
                newPost.inReplyTo = id
            }
        }
        .foregroundColor(isTargeted ? .accentColor : .secondary)
        .onDrop(of: [.image], isTargeted: $isTargeted) { providers, _ in
            guard providers.count == 1 else {
                return false
            }
            guard let provider = providers.first else {
                fatalError("No provider")
            }
            Task {
                let image = try await Resource(provider: provider)
                guard !images.contains(image) else {
                    return
                }
                images.append(image)
            }
            return true
        }
    }

    @ViewBuilder
    var footer: some View {
        Button(systemImage: "paperclip", action: {})
        Button(systemImage: "eye.trianglebadge.exclamationmark", action: {
            newPost.sensitive.toggle()
        })
        Picker("Language", selection: $newPost.language) {
            Text("\(Locale.current.localizedString(forIdentifier: Locale.current.topLevelIdentifier)!) (current)").tag(Optional<String>.none)
            Divider()
            ForEach(Locale.availableTopLevelIdentifiers.sorted(), id: \.self) { identifier in
                Text(Locale.current.localizedString(forIdentifier: identifier) ?? identifier).tag(Optional(identifier))
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        Picker("Visibility", selection: $newPost.visibility) {
            ForEach(Status.Visibility.allCases, id: \.self) { visibility in
                Text(visibility.rawValue).tag(visibility)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        Spacer()
        Text(newPost.status.count, format: .number).monospacedDigit()
        Button("Post") {
            let imageUrls = images.map(\.url)
            let newPost = newPost
            Task {
                await errorHandler { [appModel] in
                    var newPost = newPost
                    let mediaAttachments = try await withThrowingTaskGroup(of: MediaAttachment.self) { group in
                        imageUrls.forEach { url in
                            group.addTask {
                                try await appModel.service.uploadAttachment(file: url, description: "<description forthcoming>")
                            }
                        }
                        return try await Array(group)
                    }
                    newPost.mediaIds = mediaAttachments.map(\.id)
                    _ = try await appModel.service.postStatus(newPost)
                }
            }
        }
        .disabled(newPost.status.isEmpty || newPost.status.count > 500) // TODO: get limit from instance?

    }
}

extension Locale {
    var topLevelIdentifier: String {
        return String(identifier.prefix(upTo: identifier.firstIndex(of: "_") ?? identifier.endIndex))
    }

    static var availableTopLevelIdentifiers: [String] {
        Locale.availableIdentifiers.filter({ !$0.contains("_") })
    }
}

public struct Resource <Content> {
    public var url: URL
    public var content: Content
}

extension Resource: Equatable where Content: Equatable {
}

extension Resource: Hashable where Content: Hashable {
}

extension Resource: Sendable where Content: Sendable {
}

extension Resource where Content == Image {
    // swiftlint:disable:next unavailable_function
    init(provider: NSItemProvider) async throws {
#if os(macOS)
        guard let url = try await provider.loadItem(forTypeIdentifier: "public.image") as? URL else {
            fatalError("No url")
        }
        guard let nsImage = NSImage(contentsOf: url) else {
            fatalError("Could not create image")
        }
        // swiftlint:disable:next accessibility_label_for_image
        let image = Image(nsImage: nsImage)
        self = .init(url: url, content: image)
#else
        fatalError("TODO: No images yet on iOS")
#endif
    }
}
