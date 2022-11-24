import Everything
import Foundation
import SwiftUI
import UniformTypeIdentifiers

public struct Resource<Content> {
    public enum Source: Hashable, Sendable, Codable {
        case url(URL)
        case data(Data)
    }

    public var source: Source
    public var content: Content
    public var contentType: UTType?

    public init(source: Resource<Content>.Source, content: Content, contentType: UTType? = nil) {
        self.source = source
        self.content = content
        self.contentType = contentType
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
    init(url: URL, content: Content, contentType: UTType? = nil) {
        var actualContentType: UTType?
        if let contentType {
            actualContentType = contentType
        }
        else {
            actualContentType = try? url.contentType
        }
        self.init(source: .url(url), content: content, contentType: actualContentType)
    }
}

extension URL {
    var contentType: UTType? {
        get throws {
            try resourceValues(forKeys: [.contentTypeKey]).contentType
        }
    }
}

// MARK: -

public extension Resource where Content == Image {
    init(source: Source, contentType: UTType? = nil) throws {
        switch source {
        case .url(let url):
            let image = try Image(url: url)
            var actualContentType: UTType?
            if let contentType {
                actualContentType = contentType
            }
            else {
                actualContentType = try url.contentType
            }
            self = .init(source: source, content: image, contentType: actualContentType)
        case .data(let data):
            let image = try Image(data: data)
            var actualContentType: UTType?
            if let contentType {
                actualContentType = contentType
            }
            else {
                actualContentType = try ImageSource(data: data).contentType
            }
            self = .init(source: source, content: image, contentType: actualContentType)
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
        guard let url = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier) as? URL else {
            fatalError("No url")
        }
        try self.init(source: .url(url))
    }
}

public extension Resource {
    var data: Data {
        get throws {
            switch source {
            case .data(let data):
                return data
            case .url(let url):
                return try Data(contentsOf: url)
            }
        }
    }

    var filename: String? {
        switch source {
        case .data:
            return nil
        case .url(let url):
            return url.lastPathComponent
        }
    }
}

public extension Resource where Content == Image {
    var contentType: UTType? {
        get throws {
            switch source {
            case .data(let data):
                return try ImageSource(data: data).contentType
            case .url(let url):
                return UTType(filenameExtension: url.pathExtension, conformingTo: .image)
            }
        }
    }
}

// TODO: Does a video type exist in AVFoundation???
public struct Video {
    public var contentType: UTType
    public var url: URL

    public init(contentType: UTType, url: URL) {
        self.contentType = contentType
        self.url = url
    }
}

extension Video: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .video) { _ in
            unimplemented()
        }
        FileRepresentation(importedContentType: .video) { file in
            print(file)
            return Video(contentType: .video, url: file.file)
        }
        //        ProxyRepresentation { transferable in
        //            print("3")
        //            fatalError()
        //        }
    }
}
