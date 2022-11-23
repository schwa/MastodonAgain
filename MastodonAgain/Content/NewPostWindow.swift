import AsyncAlgorithms
import Everything
import Foundation
import Mastodon
import SwiftUI
import PhotosUI

enum NewPostWindow: Codable, Hashable {
    case empty
    case reply(Status.ID) // TODO: Make full status?
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
                    inReplyTo = await instanceModel.service.status(for: id)
                    newPost.inReplyTo = id
                }
            }
    }
}

struct NewPostView: View {
    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @State
    var images: [Resource<Image>] = []

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
        self._newPost = State(initialValue: newPost)
        self.inReplyTo = inReplyTo
        self._isPresented = isPresented
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
                ForEach(images, id: \.source) { image in
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
            let imageUrls = images.map { image in
                if case .url(let url) = image.source {
                    return url
                }
                else {
                    fatalError("Image without URL")
                }
            }
            let newPost = newPost
            Task {
                await errorHandler { [instanceModel] in
                    var newPost = newPost
                    let mediaAttachments = try await withThrowingTaskGroup(of: MediaAttachment.self) { group in
                        imageUrls.forEach { url in
                            group.addTask {
                                try await instanceModel.service.perform { baseURL, token in
                                    TODOMediaUpload(baseURL: baseURL, token: token, description: "<description forthcoming>", file: url)
                                }
                            }
                        }
                        return try await Array(group)
                    }
                    newPost.mediaIds = mediaAttachments.map(\.id)

                    _ = try await instanceModel.service.perform { baseURL, token in
                        MastodonAPI.Statuses.Publish(baseURL: baseURL, token: token, post: newPost)
                    }

                    await MainActor.run {
                        isPresented = false
                    }
                }
            }
        }
        .disabled(newPost.status.isEmpty || newPost.status.count > 500) // TODO: get limit from instance?
        .onChange(of: photosPickerItem) { newValue in
            guard let photosPickerItem else {
                return
            }

            print(photosPickerItem.supportedContentTypes)
            Task {
                await errorHandler {
                    let data = try await photosPickerItem.loadTransferable(type: Data.self)
                    guard let data else {
                        throw MastodonError.generic("Oops")
                    }
                        // TODO: We shouldn't have to do this...

//                    let source = try ImageSource(data: data)
//                    print(try source.properties(at: 0))
                    // TODO: Content type.


                        //FSPath.temporaryDirectory
                    let image = try Image(data: data)
                    let resource = Resource<Image>(source: .data(data), content: image)
                    await MainActor.run {
                        images.append(resource)
                    }
                }
            }
            self.photosPickerItem = nil
        }
    }
}

extension Image {
    init(data: Data) throws {
        #if os(macOS)
        guard let nsImage = NSImage(data: data) else {
            throw MastodonError.generic("Could not load image")
        }
        self = Image(nsImage: nsImage)
        #else
        guard let uiImage = UIImage(data: data) else {
            throw MastodonError.generic("Could not load image")
        }
        self = Image(uiImage: uiImage)
        #endif

    }
}
