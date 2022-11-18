import Everything
import Mastodon
import SwiftUI

struct SignInPicker: View {
    @EnvironmentObject
    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @State
    var selectedSigninID: SignIn.ID?

    var body: some View {
        ValueView(value: false) { isPresentingPicker in
            Button {
                isPresentingPicker.wrappedValue = true
            } label: {
                Label {
                    Text(instanceModel.signin.name)
                    Image(systemName: "chevron.down").controlSize(.small)
                } icon: {
                    instanceModel.signin.avatar.content.resizable().scaledToFit().frame(width: 20, height: 20).cornerRadius(4)
                }
            }
            .buttonStyle(.borderless)
            .popover(isPresented: isPresentingPicker) {
                ListPicker(values: appModel.signins, selection: $selectedSigninID) { signin in
                    Label {
                        Text(signin.name)
                    } icon: {
                        signin.avatar.content.resizable().scaledToFit().frame(width: 20, height: 20).cornerRadius(4)
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(width: 320, height: 240)
                .padding()
            }
        }
        .onChange(of: selectedSigninID) { selectedSigninID in
            guard let selectedSigninID else {
                return
            }
            guard selectedSigninID != instanceModel.signin.id else {
                return
            }
            guard let newSignin = appModel.signins.first(identifiedBy: selectedSigninID) else {
                fatalError("No signin with id \(selectedSigninID) found.")
            }
            instanceModel.signin = newSignin
        }
    }
}
