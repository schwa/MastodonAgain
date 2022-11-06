import Foundation
import SwiftUI

public struct Resource <Content> {
    public enum Source: Hashable, Sendable, Codable {
        case url(URL)
        case data(Data)
    }

    public var source: Source
    public var content: Content

    public init(source: Resource<Content>.Source, content: Content) {
        self.source = source
        self.content = content
    }
}

// MARK: -

extension Resource: Equatable where Content: Equatable {
}

extension Resource: Hashable where Content: Hashable {
}

extension Resource: Sendable where Content: Sendable {
}

// MARK: -

public extension Resource {
    init(url: URL, content: Content) {
        self.init(source: .url(url), content: content)
    }
}

// MARK: -

public extension Resource where Content == Image {
    init(source: Source) throws {
        switch source {
        case .url(let url):
            #if os(macOS)
            guard let nsImage = NSImage(contentsOf: url) else {
                fatalError("Could not create image")
            }
            let image = Image(nsImage: nsImage)
            self = .init(source: source, content: image)
            #elseif os(iOS)
            guard let uiImage = UIImage(contentsOfFile: url.path) else {
                fatalError("Could not create image")
            }
            let image = Image(uiImage: uiImage)
            self.init(source: source, content: image)
            #endif
        case .data(let data):
            #if os(macOS)
            guard let nsImage = NSImage(data: data) else {
                fatalError("TODO: Throw instead")
            }
            let image = Image(nsImage: nsImage)
            self.init(source: source, content: image)
            #elseif os(iOS)
            guard let uiImage = UIImage(data: data) else {
                fatalError("TODO: Throw instead")
            }
            let image = Image(uiImage: uiImage)
            self.init(source: source, content: image)
            #endif
        }
    }
}

extension Resource: Decodable where Content == Image {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let source = try container.decode(Source.self)
        try self.init(source: source)
    }
}

extension Resource: Encodable where Content == Image {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(source)
    }
}

// MARK: -

public extension Resource where Content == Image {
    // swiftlint:disable:next unavailable_function
    init(provider: NSItemProvider) async throws {
        guard let url = try await provider.loadItem(forTypeIdentifier: "public.image") as? URL else {
            fatalError("No url")
        }
        try self.init(source: .url(url))
    }
}
