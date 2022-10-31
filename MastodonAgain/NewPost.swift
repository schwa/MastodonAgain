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

    var body: some View {
        VStack {
            Text(verbatim: String(describing: newPost))
                .debuggingInfo()
            if let inResponseTo {
                Text("Replying to \(inResponseTo.account.acct)")
            }
            TextEditor(text: $text)
            Button("Reply") {
                Task {
                    let status = try await appModel.service.postStatus(text: text, inReplyTo: inResponseTo?.id)
                    print(status)
                    text = ""
                }
            }
            .disabled(text.isEmpty)
        }
        .padding()
        .task {
            if case let .reply(id) = newPost {
                inResponseTo = await appModel.service.status(for: id)
            }
        }
    }
}

enum NewPost: Codable, Hashable {
    case empty
    case reply(Status.ID)
}

