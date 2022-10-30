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
    func redlined() -> some View {
        modifier(RedlineModifier())
    }
}

extension Image {
    init?(blurHash: String, size: CGSize) {
        guard let cgImage = decodedBlurHash(blurHash: blurHash, size: size) else {
            return nil
        }
        self = Image(cgImage: cgImage)
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
