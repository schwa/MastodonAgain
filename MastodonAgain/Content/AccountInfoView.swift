import CachedAsyncImage
import Everything
import Mastodon
import QuickLook
import SwiftUI

struct AccountInfoView: View {
    @State
    var id: Account.ID?

    @State
    var account: Account?

    //    @Environment(\.errorHandler)
    //    var errorHandler

    //    @EnvironmentObject
    //    var appModel: AppModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    init(_ id: Account.ID?) {
        _id = State(initialValue: id)
    }

    var body: some View {
        FetchableValueView(value: $account, canRefresh: false) {
            try await self.fetch()
        } content: {
            if let account {
                ConcreteAccountInfoView(account: $account.unsafeBinding())
                    .navigationTitle("\(account.displayName)")
            }
            else {
                ProgressView()
                    .navigationTitle("Loading account…")
            }
        }
    }

    func fetch() async throws -> Account? {
        if let id {
            return try await instanceModel.service.perform { baseURL, token in
                MastodonAPI.Accounts.Retrieve(baseURL: baseURL, token: token, id: id)
            }
        }
        else {
            return instanceModel.signin.account
        }
    }
}

// MARK: -

struct ConcreteAccountInfoView: View {
    @Binding
    var account: Account

    enum TabSelection {
        case posts
        case following
        case followers
    }

    @State
    var primaryTabSelection: TabSelection = .posts

    @ViewBuilder
    var body: some View {
        ScrollView {
            VStack {
                Form {
                    header
                }
                Picker("Tab Selection", selection: $primaryTabSelection) {
                    Text("Posts \(account.statusesCount, format: .number)")
                        .tag(TabSelection.posts)
                        .fixedSize()
                    Text("Following \(account.followingCount, format: .number)")
                        .tag(TabSelection.following)
                        .fixedSize()
                    Text("Followers \(account.followersCount, format: .number)")
                        .tag(TabSelection.followers)
                        .fixedSize()
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()

                switch primaryTabSelection {
                case .posts:
                    posts
                case .following:
                    following
                case .followers:
                    followers
                }
                DebugDescriptionView(account)
                    .debuggingInfo()
            }
            .background {
                Color.white
                    .overlay(alignment: .top) {
                        CachedAsyncImage(url: account.headerStatic, urlCache: .imageCache) { image in
                            ValueView(URL?.none) { quicklookURL in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .accessibilityLabel("Background image for \(account.name)")
                                    .accessibilityAddTraits(.isButton)
                                    .onTapGesture {
                                        quicklookURL.wrappedValue = account.headerStatic
                                    }
                                    .quickLookPreview(quicklookURL)
                            }
                        } placeholder: {
                            Color.clear
                        }
                        .background {
                            LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                        .frame(maxHeight: 160)
                        .clipped()
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder
    var header: some View {
        Spacer().frame(height: 80)
        Avatar(account: account)
            .frame(maxWidth: 128, maxHeight: 128, alignment: .center)
        Text(verbatim: account.name).bold()

        HStack {
            Text(verbatim: "@\(account.shortUsername)")
            if account.locked {
                Image(systemName: "lock")
            }
            Text(verbatim: account.id.description).monospacedDigit()
        }

        if let url = account.url {
            Link("\(url, format: .url)", destination: url)
        }

        HStack {
            account.bot ? Tag("Bot") : nil
            account.locked ? Tag("Locked") : nil
            account.discoverable ?? true ? Tag("Discoverable") : nil
            account.group ? Tag("Group") : nil
            account.suspended ?? false ? Tag("Suspended") : nil
            account.limited ?? false ? Tag("Limited") : nil
        }

        LabeledContent("Note") {
            Text(account.note.safeMastodonAttributedString)
        }
        LabeledContent("Joined") {
            Text(account.created, style: .date)
        }
        LabeledContent("Fields") {
            Grid(alignment: .leading) {
                ForEach(account.fields.indices, id: \.self) { index in
                    GridRow {
                        let field = account.fields[index]
                        Text(field.name)
                        Text(field.value.safeMastodonAttributedString)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var posts: some View {
        PlaceholderShape().stroke().overlay(Text("Posts"))
    }

    @ViewBuilder
    var following: some View {
        PlaceholderShape().stroke().overlay(Text("Following"))
    }

    @ViewBuilder
    var followers: some View {
        PlaceholderShape().stroke().overlay(Text("Followers"))
    }
}

struct FetchableValueView<Value, Content>: View where Value: Sendable, Content: View {
    @Binding
    var value: Value?

    let fetch: @Sendable () async throws -> Value?
    let content: () -> Content
    let canRefresh: Bool

    @State
    var refreshing = false

    let start = Date()

    @Environment(\.errorHandler)
    var errorHandler

    init(value: Binding<Value?>, canRefresh: Bool = false, fetch: @escaping @Sendable () async throws -> Value?, @ViewBuilder content: @escaping () -> Content) {
        _value = value
        self.canRefresh = canRefresh
        self.fetch = fetch
        self.content = content
    }

    var body: some View {
        Group {
            content()
                .task {
                    value = await errorHandler { [fetch] in
                        try await fetch()
                    }
                }
        }
        .toolbar {
            if canRefresh {
                if refreshing {
                    ProgressView()
                }
                else {
                    Button("Refresh") {
                        refreshing = true
                        Task {
                            value = await errorHandler { [fetch] in
                                let value = try await fetch()
                                print("DONE")
                                MainActor.runTask {
                                    refreshing = false
                                }
                                return value
                            }
                        }
                    }
                    .disabled(value == nil)
                }
            }
        }
    }
}

struct Tag<Content>: View where Content: View {
    let content: () -> Content

    @Environment(\.backgroundStyle)
    var backgroundStyle

    init(content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
            .background(Capsule().fill(backgroundStyle ?? .init(Color.cyan)))
    }
}

extension Tag where Content == Text {
    init(_ label: String) {
        self.init {
            Text(label)
        }
    }
}
