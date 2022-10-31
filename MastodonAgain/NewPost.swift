import SwiftUI
import Mastodon

struct NewPostView: View {
    @EnvironmentObject
    var appModel: AppModel

    @Binding
    var newPost: NewPost?

    @State
    var inResponseTo: Status?

    @State
    var text = ""

    @State
    var image: Image?

    @State
    var imageURL: URL?

    @State
    var imageDescription: String = ""

    var body: some View {
        VStack {
            Text(verbatim: String(describing: newPost))
                .debuggingInfo()
            if let inResponseTo {
                Text("Replying to \(inResponseTo.account.acct)")
            }
            TextEditor(text: $text)
            HStack {
                ImageWell(image: $image, imageURL: $imageURL).frame(width: 128, height: 128)
                if image != nil {
                    TextField("Image description", text: $imageDescription)
                }
            }
            Button("Reply") {
                Task {
//                    if let imageURL = imageURL, !imageDescription.isEmpty {
//                        let status = try await appModel.service.uploadAttachment(file: imageURL, description: imageDescription)
//                        print(status)
//                    }

                    let status = try await appModel.service.postStatus(text: text, inReplyTo: inResponseTo?.id)
                    print(status)
                    text = ""
                }
            }
            .disabled(text.isEmpty || (image != nil && imageDescription.isEmpty))
        }
        .padding()
        .task {
            if case let .reply(id) = newPost {
                inResponseTo = await appModel.service.status(for: id)
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

enum NewPost: Codable, Hashable {
    case empty
    case reply(Status.ID)
}

