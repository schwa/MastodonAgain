import CachedAsyncImage
import Everything
import Foundation
import Mastodon
import RegexBuilder
import QuickLook
import SwiftUI
import UniformTypeIdentifiers
import WebKit

// swiftlint:disable file_length

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

    init(account: Account, quicklook: Bool = true) {
        self.account = account
        self.quicklook = quicklook
    }

    var body: some View {
        CachedAsyncImage(url: account.avatar, urlCache: .imageCache) { image in
            ValueView(Optional<URL>.none) { quicklookPreviewURL in
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
            Text(account)
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

struct RequestDebugView: View {
    let request: URLRequest

    @State
    var result: String?

    @Environment(\.errorHandler)
    var errorHandler

    var body: some View {
        VStack {
            Text(request.url!, format: .url)
            if let result {
                ScrollViewReader { proxy in
                    ScrollView([.vertical]) {
                        VStack {
                            Text("Body").tag("0")
                            Text(verbatim: result)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo("0", anchor: .topLeading)
                    }
                }
                .frame(minWidth: 640, minHeight: 480)
            }
            else {
                ProgressView()
            }
        }
        .task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                self.result = try jsonTidy(data: data)
            }
            catch {
            }
        }
    }
}

struct SelectionLayoutKey: LayoutValueKey {
    static var defaultValue: AnyHashable?
}

extension View {
    func selection(_ selection: AnyHashable) -> some View {
        layoutValue(key: SelectionLayoutKey.self, value: selection)
    }
}

struct SelectedView: Layout {
    let selection: AnyHashable

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = CGSize(proposal.width ?? .infinity, proposal.height ?? .infinity)
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.forEach { subview in
            let key = subview[SelectionLayoutKey.self]
            if key == selection {
                subview.place(at: bounds.origin, proposal: .init(width: bounds.width, height: bounds.height))
            }
            else {
                // Make the unselected view zero size.
                subview.place(at: .zero, proposal: .zero)
            }
        }
    }
}

struct WebView: View {
    let request: URLRequest

    var body: some View {
        ViewAdaptor {
            let webConfiguration = WKWebViewConfiguration()
            let view = WKWebView(frame: .zero, configuration: webConfiguration)
            view.load(request)
            return view
        } update: { _ in
        }
    }
}

// MARK: -

extension Bundle {
    var displayName: String? {
        // TODO: Localize?
        (infoDictionary ?? [:])["CFBundleName"] as? String
    }
}

struct ListPicker<Value, Content>: View where Value: Identifiable, Content: View {
    let values: [Value]

    @Binding
    var selection: Value.ID?

    var content: (Value) -> Content

    var body: some View {
        List(values, selection: $selection) { row in
            content(row)
        }
    }
}

struct AccountNoteEditor: View {
    @EnvironmentObject
    var stackModel: StackModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @Environment(\.errorHandler)
    var errorHandler

    let relationship: Relationship

    @Binding
    var isPresenting: Bool

    @State
    var note: String = ""

    var body: some View {
        VStack {
            TextField("Note", text: $note)
                .frame(minWidth: 240)
            HStack {
                Button("Save") { [note] in
                    Task {
                        await errorHandler {
                            _ = try await instanceModel.service.perform { baseURL, token in
                                MastodonAPI.Accounts.Note(baseURL: baseURL, token: token, id: relationship.id, comment: note)
                            }
                            await MainActor.run {
                                isPresenting = false
                            }
                        }
                    }
                }
                Button("Delete", role: .destructive) {
                    Task {
                        await errorHandler {
                            _ = try await instanceModel.service.perform { baseURL, token in
                                MastodonAPI.Accounts.Note(baseURL: baseURL, token: token, id: relationship.id, comment: nil)
                            }
                            await MainActor.run {
                                isPresenting = false
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            note = relationship.note ?? ""
        }
    }
}

struct ImageToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() }
        label: {
            if configuration.isOn {
                Image(systemName: "ladybug").foregroundColor(.red).symbolVariant(.circle)
            }
            else {
                Image(systemName: "ladybug")
            }
        }
    }
}

extension UUID: RawRepresentable {
    public init?(rawValue: String) {
        self = UUID(uuidString: rawValue)!
    }

    public var rawValue: String {
        uuidString
    }
}

extension CaseIterable where Self: Equatable {
    func nextWrapping() -> Self {
        next(wraps: true)! // TODO: can improve this
    }

    func next(wraps: Bool = false) -> Self? {
        let allCases = Self.allCases
        let index = allCases.index(after: allCases.firstIndex(of: self)!)
        if index == allCases.endIndex {
            return wraps ? allCases.first! : nil
        }
        else {
            return allCases[index]
        }
    }
}

extension Collection {
    func nilify() -> Self? {
        if isEmpty {
            return nil
        }
        else {
            return self
        }
    }
}

extension Text {
    init(_ account: Account) {
        var text = Text("")
        if !account.displayName.isEmpty {
            // swiftlint:disable shorthand_operator
            text = text + Text("\(account.displayName)").bold()
        }
        self = text + Text(" ") + Text("@\(account.acct)")
            .foregroundColor(.secondary)
    }
}

extension Collection<Text> {
    func joined(separator: Text) -> Text {
        reduce(Text("")) { partialResult, element in
            partialResult + separator + element
        }
    }
}

extension NSItemProvider: @unchecked Sendable {
}

extension View {
    func logging(_ s: String) -> Self {
        appLogger?.log("\(s)")
        return self
    }
}

struct JSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(_ value: some Codable, encoder: JSONEncoder = JSONEncoder()) throws {
        data = try encoder.encode(value)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw MastodonError.generic("Could not read file")
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension View {
    @ViewBuilder
    func hidden(_ hide: Bool) -> some View {
        if hide {
            hidden()
        }
        else {
            self
        }
    }
}

public extension ValueView {
    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self.init(value: value, content: content)
    }
}

extension View {
    @ViewBuilder
    func conditional(_ condition: Bool, @ViewBuilder transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        }
        else {
            self
        }
    }
}
