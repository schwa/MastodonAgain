import CachedAsyncImage
import Everything
import Mastodon
import RegexBuilder
import SwiftUI

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
    let url: URL

    var body: some View {
        CachedAsyncImage(url: url) { image in
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
    }
}

public extension ErrorHandler {
    func handle(_ block: () async throws -> Void) async {
        do {
            try await block()
        }
        catch {
            Task {
                await MainActor.run {
                    handle(error: error)
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

public extension Button {
    init(title: String, systemImage systemName: String, action: @escaping () async -> Void) where Label == SwiftUI.Label<Text, Image> {
        self = Button(action: {
            Task {
                await action()
            }
        }, label: {
            SwiftUI.Label(title, systemImage: systemName)
        })
    }

    init(systemImage systemName: String, action: @escaping () async -> Void) where Label == Image {
        self = Button(action: {
            Task {
                await action()
            }
        }, label: {
            Image(systemName: systemName)
        })
    }

    init(action: @escaping () async -> Void, @ViewBuilder label: () -> Label) {
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
            .foregroundColor(configuration.isPressed ? Color.primary : Color.secondary)
            .labelStyle(ActionButtonLabelStyle())
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
        self.modifier(DebuggingInfoModifier())
    }
}

extension Path {
    init(_ rectSize: CGSize) {
        self = Path(CGRect(size: rectSize))
    }
}

extension FSPath {
    func reveal() {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}

struct DebugDescriptionView <Value>: View {
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
