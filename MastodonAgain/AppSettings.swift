import SwiftUI
import Mastodon

struct AppSettings: View {

    @EnvironmentObject
    var appModel: AppModel

    var body: some View {
        List {
            Form {
//                if let application = registeredApplication {
//                    Section("Application") {
//                        LabeledContent("id", value: String(describing: application.id))
//                        LabeledContent("name", value: application.name)
//                        LabeledContent("website", value: application.website)
//                        LabeledContent("redirectURI", value: application.redirectURI)
//                        LabeledContent("clientID", value: application.clientID)
//                        LabeledContent("clientSecret", value: application.clientSecret)
//                        LabeledContent("vapidKey", value: application.vapidKey)
//                    }
//                }
//                if let token = token {
//                    Section("Token") {
//                        LabeledContent("accessToken", value: token.accessToken)
//                        LabeledContent("tokenType", value: token.tokenType)
//                        LabeledContent("scope", value: token.scope)
//                        LabeledContent("created", value: "\(token.created, format: .dateTime)")
//                    }
//                }
                Button("Log out") {
                    appModel.authorization = .unauthorized
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .padding()
    }



}
