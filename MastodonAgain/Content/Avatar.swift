import CachedAsyncImage
import Everything
import Mastodon
import SwiftUI

struct Avatar: View {
    @EnvironmentObject
    var stackModel: StackModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @Environment(\.errorHandler)
    var errorHandler

    @State
    var relationship: Relationship?

    @State
    var isNoteEditorPresented = false

    let account: Account
    let quicklook: Bool

    init(account: Account, quicklook: Bool = true, itMe: Bool = false) {
        self.account = account
        self.quicklook = quicklook
    }

    var body: some View {
        CachedAsyncImage(url: account.avatar, urlCache: .imageCache) { image in
            ValueView(URL?.none) { quicklookPreviewURL in
                image
                    .resizable()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4).strokeBorder(lineWidth: 2).foregroundColor(Color.gray)
                    }
                    .accessibilityLabel("Avatar icon for \(account.name)")
                    .conditional(quicklook) { view in
                        view.accessibilityAddTraits(.isButton)
                            .onTapGesture {
                                if quicklook {
                                    quicklookPreviewURL.wrappedValue = account.avatar
                                }
                            }
                            .quickLookPreview(quicklookPreviewURL)
                    }
            }
        } placeholder: {
            Image(systemName: "person.circle.fill")
                .accessibilityLabel("Placeholder icon for \(account.name)")
        }
        .aspectRatio(1.0, contentMode: .fit)
        .task {
            guard itMe == false else {
                return
            }
            await errorHandler { [instanceModel, account] in
                let channel = await instanceModel.service.broadcaster(for: .relationships, element: [Account.ID: Relationship].self).makeChannel()
                Task {
                    for await relationships in channel {
                        if let relationship = relationships[account.id] {
                            await MainActor.run {
                                self.relationship = relationship
                            }
                        }
                    }
                }
                try await instanceModel.service.fetchRelationships(ids: [account.id])
            }
        }
        .contextMenu {
            Text(account.name).bold() + Text("@\(account.shortUsername)").foregroundColor(.secondary)

            Button("Info") {
                stackModel.path.append(Page(id: .account, subject: account.id))
            }
            if let relationship {
                if relationship.following {
                    unfollow
                    if relationship.showingReblogs {
                        disableReposts
                    }
                }
                Button("Edit Note…") {
                    isNoteEditorPresented = true
                }
            }
            else {
                Text("Fetching relationship...")
            }
        }
        .popover(isPresented: $isNoteEditorPresented) {
            AccountNoteEditor(relationship: relationship!, isPresenting: $isNoteEditorPresented)
        }
    }

    var itMe: Bool {
        account.id == instanceModel.signin.account.id
    }

    @ViewBuilder
    var unfollow: some View {
        Button("Unfollow") {
            await errorHandler {
                let relationship = try await instanceModel.service.perform { baseURL, token in
                    MastodonAPI.Accounts.Unfollow(baseURL: baseURL, token: token, id: account.id)
                }
                appLogger?.info("You have unfollowed \(account.acct)")
                MainActor.runTask {
                    self.relationship = relationship
                }
            }
        }
    }

    @ViewBuilder
    var disableReposts: some View {
        Button("Disable Reposts") {
            await errorHandler {
                let relationship = try await instanceModel.service.perform { baseURL, token in
                    MastodonAPI.Accounts.Follow(baseURL: baseURL, token: token, id: account.id, reblogs: false)
                }
                appLogger?.info("You have disabled reblogs for \(account.acct)")
                MainActor.runTask {
                    self.relationship = relationship
                }
            }
        }
    }
}
