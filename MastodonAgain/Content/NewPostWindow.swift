import Algorithms
import AsyncAlgorithms
import Everything
import Foundation
import Mastodon
import PhotosUI
import SwiftUI

enum NewPostWindow: Codable, Hashable {
    case empty
    case reply(Status.ID) // Cant use Status as Status is not hashable.
}

struct NewPostHost: View {
    @EnvironmentObject
    var instanceModel: InstanceModel

    @Binding
    var open: NewPostWindow?

    @State
    var inReplyTo: Status?

    @State
    var newPost: NewPost

    init(open: Binding<NewPostWindow?>) {
        _open = open
        _newPost = State(initialValue: NewPost())
    }

    var body: some View {
        // TODO: isPresented
        NewPostView(newPost: newPost, isPresented: .constant(true))
            .task {
                if case .reply(let id) = open {
//                    inReplyTo = await instanceModel.service.status(for: id)
                    newPost.inReplyTo = id
                }
            }
    }
}

// MARK: -

struct NewPostView: View {
    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @State
    var mediaUploads: [Upload] = []

    @State
    var isTargeted = false

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var newPost: NewPost

    let inReplyTo: Status?

    @Binding
    var isPresented: Bool

    init(newPost: NewPost = NewPost(), inReplyTo: Status? = nil, isPresented: Binding<Bool>) {
        _newPost = State(initialValue: newPost)
        self.inReplyTo = inReplyTo
        _isPresented = isPresented
    }

    // TODO: this needs a pretty healthy cleanup

    var body: some View {
        VStack {
            VStack {
                DebugDescriptionView(newPost)
            }
            .debuggingInfo()
            if let inReplyTo {
                Text("Replying to \(inReplyTo.account.name)")
            }
            TextEditor(text: $newPost.status)
            HStack {
                ForEach(mediaUploads.indexed(), id: \.0) { _, upload in
                    // TODO: Gross (all those ?)
                    if let thumbnail = try? upload.thumbnail?() {
                        thumbnail.resizable().scaledToFit()
                            .frame(maxWidth: 80, maxHeight: 80, alignment: .trailing)
                    }
                    else {
                        Image(systemName: "questionmark.square.dashed")
                    }
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
        .foregroundColor(isTargeted ? .accentColor : .secondary)
        .onDrop(of: [.image], isTargeted: $isTargeted) { providers, _ in
            guard providers.count == 1 else {
                return false
            }
            guard let provider = providers.first else {
                fatalError("No provider")
            }
            Task {
                let resource = try await Resource(provider: provider)
                guard let filename = resource.filename, let contentType = try resource.contentType else {
                    fatalError("No filename or no contentType.")
                }
                let upload = Upload(filename: filename, contentType: contentType, thumbnail: { resource.content }, content: { try resource.data })
                mediaUploads.append(upload)
            }
            return true
        }
        .onChange(of: photosPickerItem) { photosPickerItem in
            guard let photosPickerItem else {
                return
            }
            updatePhotosPickerItem(photosPickerItem)
        }
    }

    @State
    var photosPickerItem: PhotosPickerItem?

    @ViewBuilder
    var footer: some View {
        PhotosPicker(selection: $photosPickerItem, preferredItemEncoding: .compatible) {
            Image(systemName: "paperclip")
        }

        Button(systemImage: "eye.trianglebadge.exclamationmark", action: {
            newPost.sensitive.toggle()
        })

        Picker("Language", selection: $newPost.language) {
            Text("\(Locale.current.localizedString(forIdentifier: Locale.current.topLevelIdentifier)!) (current)").tag(String?.none)
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
            post()
        }
        .disabled(newPost.status.isEmpty || newPost.status.count > 500) // TODO: get limit from instance?
    }

    func updatePhotosPickerItem(_ photosPickerItem: PhotosPickerItem) {
        Task {
            await errorHandler {
                if let video = try await photosPickerItem.loadTransferable(type: Video.self) {
                    print(video)
                }

                let data = try await photosPickerItem.loadTransferable(type: Data.self)
                guard let data else {
                    throw MastodonError.generic("loadTransferable returned nil.")
                }
                // TODO: this may not even be an image?!?!?!?!?!?
                let source = try ImageSource(data: data)
                guard let type = source.contentType, let filenameExtension = type.preferredFilenameExtension else {
                    throw MastodonError.generic("No idea of the content type for that upload")
                }
                let filename = "Untitled.\(filenameExtension)"

                // TODO: get thumbnail from image source
                // swiftlint:disable:next accessibility_label_for_image
                let upload = Upload(filename: filename, contentType: type, thumbnail: { try Image(data: data) }, content: { data })
                await MainActor.run {
                    mediaUploads.append(upload)
                }
            }
        }
        self.photosPickerItem = nil
    }

    func post() {
        Task {
            await errorHandler { [instanceModel, newPost] in
                var newPost = newPost
                let mediaAttachments = try await withThrowingTaskGroup(of: MediaAttachment.self) { group in
                    await mediaUploads.forEach { upload in
                        group.addTask {
                            try await instanceModel.service.perform { baseURL, token in
                                TODOMediaUpload(baseURL: baseURL, token: token, description: "<description forthcoming>", upload: upload)
                            }
                        }
                    }
                    return try await Array(group)
                }
                newPost.mediaIds = mediaAttachments.map(\.id)
                _ = try await instanceModel.service.perform { [newPost] baseURL, token in
                    MastodonAPI.Statuses.Publish(baseURL: baseURL, token: token, post: newPost)
                }
                await MainActor.run {
                    isPresented = false
                }
            }
        }
    }
}
