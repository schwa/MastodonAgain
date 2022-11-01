import SwiftUI
import Mastodon

// https://docs.joinmastodon.org/methods/statuses/
struct NewPost {
    var status: String
    var inResponseTo: Status?
    var mediaIds: [MediaAttachment.ID]?
    // pool
    var sensitive: Bool
    var spoiler: String
    var visibility: Status.Visibility
    var scheduleAt: Date?
    var language: String
}

struct NewPostView: View {
    @EnvironmentObject
    var appModel: AppModel

    @Binding
    var open: NewPostWindow?

    @State
    var newPost: NewPost

    init(open: Binding<NewPostWindow?>) {
        self._open = open
        self._newPost = State(initialValue: NewPost(status: "", sensitive: false, spoiler: "", visibility: .public, language: "en"))
    }

    var body: some View {
        VStack {
            VStack {
                DebugDescriptionView(open)
                DebugDescriptionView(newPost)
            }
            .debuggingInfo()
            if let inResponseTo = newPost.inResponseTo {
                Text("Replying to \(inResponseTo.account.acct)") // TODO: use full name
            }
            TextEditor(text: $newPost.status)
            if newPost.sensitive {
                TextField("Content Warning", text: $newPost.spoiler)
            }
            HStack {
                Button(systemImage: "paperclip", action: {})
                Button(systemImage: "gear", action: {})
                Button(systemImage: "eye.trianglebadge.exclamationmark", action: {
                    newPost.sensitive.toggle()
                })
                Picker("Language", selection: $newPost.language) {
                    Text("en").tag("en")
                }
                .pickerStyle(.menu)
                Picker("Visibility", selection: $newPost.visibility) {
                    ForEach(Status.Visibility.allCases, id: \.self) { visibility in
                        Text(visibility.rawValue).tag(visibility)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                Text(newPost.status.count, format: .number).monospacedDigit()
                Button("Reply") {
                    Task {
                        let status = try await appModel.service.postStatus(text: newPost.status, inReplyTo: newPost.inResponseTo?.id)
                        print(status)
                        newPost.status = ""
                    }
                }
                .disabled(newPost.status.isEmpty)
            }
        }
        .padding()
        .task {
            if case let .reply(id) = open {
                newPost.inResponseTo = await appModel.service.status(for: id)
            }
        }
    }
}

struct ImageWell: View {
    @Binding
    var image: Image?

    @Binding
    var imageURL: URL?

    @State
    var isTargeted = false

    var body: some View {
        if let image {
            image.resizable().scaledToFit()
        }
        else {
            Image(systemName: "photo").resizable().scaledToFit()
                .padding()
                .foregroundColor(isTargeted ? .accentColor : .secondary)
                .onDrop(of: [.image], isTargeted: $isTargeted) { providers, _ in
                    guard providers.count == 1 else {
                        return false
                    }
                    guard let provider = providers.first else {
                        fatalError("No provider")
                    }
                    Task {
                        guard let url = try await provider.loadItem(forTypeIdentifier: "public.image") as? URL else {
                            fatalError("No url")
                        }
                        #if os(macOS)
                        guard let nsImage = NSImage(contentsOf: url) else {
                            fatalError("Could not create image")
                        }
                        self.imageURL = url
                        self.image = Image(nsImage: nsImage)
                        #else
                        fatalError("TODO: No images yet on iOS")
                        #endif
                    }
                    return true
                }
        }
    }
}

enum NewPostWindow: Codable, Hashable {
    case empty
    case reply(Status.ID) // TODO: Make full status?
}

//HStack {
//    ImageWell(image: $image, imageURL: $imageURL).frame(width: 128, height: 128)
//    if image != nil {
//        TextField("Image description", text: $imageDescription)
//    }
//}

//                    if let imageURL = imageURL, !imageDescription.isEmpty {
//                        let status = try await appModel.service.uploadAttachment(file: imageURL, description: imageDescription)
//                        print(status)
//                    }

