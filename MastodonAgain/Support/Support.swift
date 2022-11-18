import CachedAsyncImage
import Everything
import Foundation
import Mastodon
import RegexBuilder
import SwiftUI
import WebKit

// swiftlint:disable file_length

struct RedlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    Canvas { context, size in
                        let r = CGRect(origin: .zero, size: size)
                        let lines: [(CGPoint, CGPoint)] = [
                            (r.minXMidY, r.maxXMidY),
                            (r.minXMidY + [0, -r.height * 0.25], r.minXMidY + [0, r.height * 0.25]),
                            (r.maxXMidY + [0, -r.height * 0.25], r.maxXMidY + [0, r.height * 0.25]),

                            (r.midXMinY, r.midXMaxY),
                            (r.midXMinY + [-r.width * 0.25, 0], r.midXMinY + [r.width * 0.25, 0]),
                            (r.midXMaxY + [-r.width * 0.25, 0], r.midXMaxY + [r.width * 0.25, 0]),
                        ]

                        context.stroke(Path(lines: lines), with: .color(.white.opacity(0.5)), lineWidth: 3)
                        context.stroke(Path(lines: lines), with: .color(.red), lineWidth: 1)
                        if let symbol = context.resolveSymbol(id: "width") {
                            context.draw(symbol, at: (r.midXMidY + r.minXMidY) / 2, anchor: .center)
                        }
                        if let symbol = context.resolveSymbol(id: "height") {
                            context.draw(symbol, at: (r.midXMidY + r.midXMinY) / 2, anchor: .center)
                        }
                    }
                symbols: {
                    Text(verbatim: "\(proxy.size.width, format: .number)")
                        .padding(1)
                        .background(.thickMaterial)
                        .tag("width")
                    Text(verbatim: "\(proxy.size.height, format: .number)")
                        .padding(1)
                        .background(.thickMaterial)
                        .tag("height")
                }
                }
            }
    }
}

extension View {
    @ViewBuilder
    func redlined(_ enabled: Bool = true) -> some View {
        if enabled {
            modifier(RedlineModifier())
        }
        else {
            self
        }
    }
}

struct Avatar: View {
    @EnvironmentObject
    var stackModel: StackModel

    @EnvironmentObject
    var instanceModel: InstanceModel

    @Environment(\.errorHandler)
    var errorHandler

    let account: Account

    @State
    var relationship: Relationship?

    @State
    var isNoteEditorPresented = false

    var body: some View {
        CachedAsyncImage(url: account.avatar) { image in
            image
                .resizable()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4).strokeBorder(lineWidth: 2).foregroundColor(Color.gray)
                }
        } placeholder: {
            Image(systemName: "person.circle.fill")
        }
        .task {
            // TODO: this hits the server once per view. WE can batch requests into a single relationships fetch
            await updateRelationship()
        }
        .contextMenu {
            Text(account)
            Button("Info") {
                stackModel.path.append(.account(account.id))
            }
            if let relationship {
                if relationship.following {
                    Button("Unfollow") {
                        await errorHandler {
                            _ = try await instanceModel.service.perform(type: Relationship.self, { baseURL, token in
                                MastodonAPI.Accounts.Unfollow(baseURL: baseURL, token: token, id: account.id)
                            })
                            appLogger?.info("You have unfollowed \(account.acct)")
                            await updateRelationship()
                        }
                    }
                    if relationship.showingReblogs {
                        Button("Disable Reposts") {
                            await errorHandler {
                                _ = try await instanceModel.service.perform(type: Relationship.self, { baseURL, token in
                                    MastodonAPI.Accounts.Follow(baseURL: baseURL, token: token, id: account.id, reblogs: false)
                                })
                                appLogger?.info("You have disabled reblogs for \(account.acct)")
                                await updateRelationship()
                            }
                        }
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
        //        .alert(isPresented: $isNoteEditorPresented) {
        //                        TextField("Hello world", text: .constant("Note"))
        //        }
        .popover(isPresented: $isNoteEditorPresented) {
            AccountNoteEditor(relationship: relationship!, isPresenting: $isNoteEditorPresented)
        }
        .onChange(of: isNoteEditorPresented) { _ in
            Task {
                await updateRelationship()
            }
        }
    }

    func updateRelationship() async {
        do {
            let service = instanceModel.service
            let relationships = try await service.perform(type: [Relationship].self) { baseURL, token in
                MastodonAPI.Accounts.Relationships(baseURL: baseURL, token: token, ids: [account.id])
            }
            guard let relationship = relationships.first else {
                throw MastodonError.generic("No relationship found")
            }
            await MainActor.run {
                self.relationship = relationship
            }
        }
        catch {
            appLogger?.error("Error \(error)")
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

public extension Button {
    init(title: String, systemImage systemName: String, action: @escaping @Sendable () async -> Void) where Label == SwiftUI.Label<Text, Image> {
        self = Button(action: {
            Task {
                await action()
            }
        }, label: {
            SwiftUI.Label(title, systemImage: systemName)
        })
    }

    init(_ title: String, action: @escaping @Sendable () async -> Void) where Label == Text {
        self = Button(title) {
            Task {
                await action()
            }
        }
    }

    init(systemImage systemName: String, action: @escaping @Sendable () async -> Void) where Label == Image {
        self = Button(action: {
            Task {
                await action()
            }
        }, label: {
            Image(systemName: systemName)
        })
    }

    init(action: @Sendable @escaping () async -> Void, @ViewBuilder label: () -> Label) {
        self = Button(action: {
            Task {
                await action()
            }
        }, label: {
            label()
        })
    }
}

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(ActionButtonLabelStyle())
            .foregroundColor(configuration.isPressed ? Color.primary : Color.secondary)
            .background((configuration.isPressed ? .thickMaterial : .bar))
            .cornerRadius(2)
    }
}

struct ActionButtonLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.icon
            configuration.title.font(.caption)
        }
    }
}

struct WorkInProgressView: View {
    var body: some View {
        let tileSize = CGSize(16, 16)
        // swiftlint:disable:next accessibility_label_for_image
        let tile = Image(size: tileSize) { context in
            context.fill(Path(tileSize), with: .color(.black))
            context.fill(Path(vertices: [[0.0, 0.0], [0.0, 0.5], [0.5, 0]].map { $0 * CGPoint(tileSize) }), with: .color(.yellow))
            context.fill(Path(vertices: [[0.0, 1], [1.0, 0.0], [1, 0.5], [0.5, 1]].map { $0 * CGPoint(tileSize) }), with: .color(.yellow))
        }
        Canvas { context, size in
            context.fill(Path(size), with: .tiledImage(tile, sourceRect: CGRect(size: tileSize)))
        }
    }
}

struct DebuggingInfoModifier: ViewModifier {
    @AppStorage("showDebuggingInfo")
    var showDebuggingInfo = false

    func body(content: Content) -> some View {
        if showDebuggingInfo {
            content
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .padding(4)
                .background {
                    WorkInProgressView()
                        .opacity(0.1)
                }
        }
    }
}

extension View {
    func debuggingInfo() -> some View {
        modifier(DebuggingInfoModifier())
    }
}

extension Path {
    init(_ rectSize: CGSize) {
        self = Path(CGRect(size: rectSize))
    }
}

extension FSPath {
#if os(macOS)
    func reveal() {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
#endif
}

struct DebugDescriptionView<Value>: View {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }

    var body: some View {
        Group {
            if let value = value as? CustomDebugStringConvertible {
                Text(verbatim: "\(value.debugDescription)")
            }
            else if let value = value as? CustomStringConvertible {
                Text(verbatim: "\(value.description)")
            }
            else {
                Text(verbatim: "\(String(describing: value))")
            }
        }
        .textSelection(.enabled)
        .font(.body.monospaced())
    }
}

extension ErrorHandler {
    // TODO: should block be @Sendable
    func callAsFunction<R>(_ block: @Sendable () async throws -> R?) async -> R? where R: Sendable {
        do {
            return try await block()
        }
        catch {
            handle(error: error)
            return nil
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

// TODO: Rename
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

struct FetchableValueView<Value, Content>: View where Value: Sendable, Content: View {
    @State
    var value: Value?

    let fetch: @Sendable () async throws -> Value?
    let content: (Value) -> Content
    let canRefresh: Bool

    @State
    var refreshing = false

    let start = Date()

    @Environment(\.errorHandler)
    var errorHandler

    init(value: Value? = nil, canRefresh: Bool = false, fetch: @escaping @Sendable () async throws -> Value?, content: @escaping (Value) -> Content) {
        _value = State(initialValue: value)
        self.canRefresh = canRefresh
        self.fetch = fetch
        self.content = content
    }

    var body: some View {
        Group {
            if let value {
                content(value)
            }
            else {
                VStack {
                    ProgressView()
                    Text("Fetching (") + Text(start, style: .relative) + Text(")")
                }
                .task {
                    value = await errorHandler { [fetch] in
                        try await fetch()
                    }
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

@propertyWrapper
struct Stored<Value>: DynamicProperty where Value: Codable {
    let key: String
    let defaultValue: Value

    class Cache: ObservableObject {
        @Published
        var value: Value?
    }

    @StateObject
    var cache = Cache()

    @MainActor
    var wrappedValue: Value {
        get {
            let value = Storage.shared[key].map { try! JSONDecoder().decode(Value.self, from: $0) } ?? defaultValue
            return value
        }
        nonmutating set {
            let data = try! JSONEncoder().encode(newValue)
            Storage.shared[key] = data
            cache.value = newValue
        }
    }

    init(wrappedValue: Value, _ key: String) {
        defaultValue = wrappedValue
        self.key = key
    }
}

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
            TextField("Hello world", text: $note)
                .frame(minWidth: 240)
            HStack {
                buttons
            }
        }
        .padding()
        .onAppear {
            note = relationship.note ?? ""
        }
    }

    @ViewBuilder
    var buttons: some View {
        Button("Cancel") {
            isPresenting = false
        }
        Button("Save") { [note] in
            Task {
                await errorHandler {
                    let result = try await instanceModel.service.perform(type: Relationship.self) { baseURL, token in
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
                    let result = try await instanceModel.service.perform(type: Relationship.self) { baseURL, token in
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
