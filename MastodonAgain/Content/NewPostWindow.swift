import Algorithms
import AsyncAlgorithms
@_spi(SPI) import Everything
import Foundation
import Mastodon
import PhotosUI
import QuickLook
import SwiftUI

enum NewPostWindow: Codable, Hashable {
    case empty
    case reply(Status.ID) // Cant use Status as Status is not hashable.
}

// MARK: -

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
    var mediaUploads: [MediaUpload] = []

    @State
    var isTargeted = false

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var newPost: NewPost

    @State
    var photosPickerItem: PhotosPickerItem?

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
            DebugDescriptionView(newPost)
                .debuggingInfo()
            if let inReplyTo {
                Text("Replying to \(inReplyTo.account.name)")
            }
            TextEditor(text: $newPost.status)
                .font(.body)
                .foregroundColor(.primary)

            MediaPicker(mediaUploads: $mediaUploads, photosPickerItem: $photosPickerItem)

            if newPost.sensitive {
                LabeledContent("Content Warning") {
                    TextField("Content Warning", text: $newPost.spoiler.unwrappingRebound(default: { "" }))
                }
            }
            footer
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
                guard let filename = resource.filename else {
                    fatalError("No filename or no contentType.")
                }

                let upload = try MediaUpload(name: filename, data: try resource.data)
                mediaUploads.append(upload)
                // TODO:
//                selection = upload.id
            }
            return true
        }
    }

    @ViewBuilder
    var footer: some View {
        HStack {
            PhotosPicker(selection: $photosPickerItem, preferredItemEncoding: .compatible) {
                Image(systemName: "photo")
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
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(newPost.status.isEmpty || newPost.status.count > 500) // TODO: get limit from instance?
        }
    }

    func post() {
        Task {
            await errorHandler { [instanceModel, newPost] in
                var newPost = newPost
                let mediaAttachments = try await withThrowingTaskGroup(of: MediaAttachment.self) { group in
                    try await mediaUploads.forEach { mediaUpload in
                        let upload = try mediaUpload.upload
                        group.addTask {
                            try await instanceModel.service.perform { baseURL, token in
                                TODOMediaUpload(baseURL: baseURL, token: token, description: mediaUpload.descriptiveText, upload: upload)
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

// MARK: -

struct MediaUpload: Identifiable {
    var id = UUID()
    var url: URL
    var contentType: UTType
    var thumbnail: Image
    var descriptiveText: String
}

extension MediaUpload {
    init(name: String, data: Data) throws {
        let source = try ImageSource(data: data)
        guard let contentType = source.contentType, let filenameExtension = contentType.preferredFilenameExtension else {
            throw MastodonError.generic("No idea of the content type for that upload")
        }
        self.contentType = contentType

        // TODO: at this point can use image for thumbnail
        let cgImage = try source.image(at: 0)
        thumbnail = Image(cgImage: try source.thumbnail2(at: 0))

        descriptiveText = ImageDescription(image: cgImage).descriptiveText

        let filename = name.contains(".") ? name : "\(name).\(filenameExtension)"
        let path = FSPath.temporaryDirectory / filename
        try data.write(to: path.url)
        url = path.url
    }

    var upload: Upload {
        get throws {
            let data = try Data(contentsOf: url)
            return Upload(filename: url.lastPathComponent, contentType: contentType, thumbnail: thumbnail, content: data)
        }
    }
}

// MARK: -

struct MediaPicker: View {
    @Binding
    var mediaUploads: [MediaUpload]

    @Binding
    var photosPickerItem: PhotosPickerItem?

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var nextID = 1

    // ISSUE: https://github.com/schwa/MastodonAgain/issues/78 -- selecting text unselects the thumbnail which unselects the text
    @FocusState
    var selection: MediaUpload.ID?

    @State
    var quicklookURL: URL?

    var body: some View {
        Group {
            if !mediaUploads.isEmpty {
                HStack {
                    ForEach(mediaUploads) { upload in
                        view(for: upload)
                    }
                    #if os(macOS)
                    .focusable(true)
                    #endif
                    .quickLookPreview($quicklookURL, in: mediaUploads.map(\.url))
                }
                .frame(maxHeight: 80)
                LabeledContent("Media Description") {
                    TextField("Media Description", text: Binding(get: {
                        guard let index = mediaUploads.firstIndex(where: { $0.id == selection }) else {
                            return ""
                        }
                        return mediaUploads[index].descriptiveText
                    }, set: { newValue in
                        guard let index = mediaUploads.firstIndex(where: { $0.id == selection }) else {
                            return
                        }
                        mediaUploads[index].descriptiveText = newValue
                    }))
                    .disabled(selection == nil)
                }
            }
        }
        .onChange(of: photosPickerItem) { photosPickerItem in
            guard let photosPickerItem else {
                return
            }
            updatePhotosPickerItem(photosPickerItem)
        }
    }

    @ViewBuilder
    func view(for upload: MediaUpload) -> some View {
        upload.thumbnail
            .resizable().scaledToFit().aspectRatio(1.0, contentMode: .fit)
        #if os(macOS)
            .focusable(true)
        #endif
            .focused($selection, equals: upload.id)

            .onTapGesture {
                selection = upload.id
            }
            .onLongPressGesture {
                quicklookURL = upload.url
            }

            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Thumbnail for media upload")

        #if os(macOS)
            .onDeleteCommand(perform: {
                mediaUploads.removeAll(where: { $0.id == upload.id })
            })
        #endif
            // TODO: overlay an X button to delete media.
            .contextMenu {
                Button("Remove") {
                    mediaUploads.removeAll(where: { $0.id == upload.id })
                }
            }
    }

    func updatePhotosPickerItem(_ photosPickerItem: PhotosPickerItem) {
        Task {
            await errorHandler {
//                if let video = try await photosPickerItem.loadTransferable(type: Video.self) {
//                    print(video)
//                }

                guard let data = try await photosPickerItem.loadTransferable(type: Data.self) else {
                    throw MastodonError.generic("Could not load data")
                }
                let upload = try MediaUpload(name: "Untitled \(nextID)", data: data)
                nextID += 1
                await MainActor.run {
                    mediaUploads.append(upload)
                    selection = upload.id
                }
            }
        }
        self.photosPickerItem = nil
    }
}

extension Binding where Value: Identifiable {
    init<C>(_ collection: Binding<C>, id: Value.ID) where C: MutableCollection, C.Element == Value {
        self = .init(get: {
            collection.wrappedValue[collection.wrappedValue.firstIndex(where: { $0.id == id })!]
        }, set: { newValue in
            collection.wrappedValue[collection.wrappedValue.firstIndex(where: { $0.id == id })!] = newValue
        })
    }
}

// struct Carousel: View {
//
//
// }

public extension ImageSource {
    func thumbnail2(at index: Int) throws -> CGImage {
        let options = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, index, options as CFDictionary) else {
            throw ImageSourceError.thumbnailCreationFailure
        }
        return image
    }
}
