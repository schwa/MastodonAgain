import Foundation
import UniformTypeIdentifiers

public struct JSONBody<Content> where Content: Codable {
    public let contentType = "application/json"
    public let content: Content
    public let encoder: JSONEncoder

    public init(content: Content, encoder: JSONEncoder = JSONEncoder()) {
        self.content = content
        self.encoder = encoder
    }

    public func toData() throws -> some DataProtocol {
        try JSONEncoder().encode(content)
    }
}

@available(*, deprecated, message: "Deprecated")
public struct FormBody {
    public let contentType = "application/x-www-form-urlencoded; charset=utf-8"
    public let content: [String: String]

    public init(content: [String: String]) {
        self.content = content
    }

    public func toData() throws -> some DataProtocol {
        let bodyString = content.map { key, value in
            let key = key
                .replacing(" ", with: "+")
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics + .punctuationCharacters + "+")!
            let value = value
                .replacing(" ", with: "+")
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics + .punctuationCharacters + "+")!
            return "\(key)=\(value)"
        }
        .joined(separator: "&")
        return bodyString.data(using: .utf8)!
    }
}

public struct MultipartForm {
    public struct FormValue {
        internal let data: (_ name: String) -> Data

        public init(data: @escaping (String) -> Data) {
            self.data = data
        }

        public static func value(_ value: String) -> FormValue {
            FormValue { name in
                let lines = [
                    "Content-Disposition: form-data; name=\"\(name)\"",
                    "",
                    value,
                    "",
                ]
                return Data(lines.joined(separator: "\r\n").utf8)
            }
        }

        public static func file(filename: String, mimetype: String, content: Data) -> FormValue {
            FormValue { name in
                let lines = [
                    "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"",
                    "Content-Type: \(mimetype)",
                    "",
                ]
                let header = Data(lines.joined(separator: "\r\n").utf8)
                return header + content + Data("\r\n".utf8)
            }
        }

        public static func file(filename: String, type: UTType, content: Data) throws -> FormValue {
            guard let mimetype = type.preferredMIMEType else {
                throw BlueprintError.unknown
            }
            return file(filename: filename, mimetype: mimetype, content: content)
        }

        public static func file(filename: String, content: Data) throws -> FormValue {
            guard let filenameExtension = filename.split(whereSeparator: { $0 == "." }).last.map(String.init) else {
                throw BlueprintError.unknown
            }
            guard let type = UTType(tag: filenameExtension, tagClass: .filenameExtension, conformingTo: nil) else {
                throw BlueprintError.unknown
            }
            return try file(filename: filename, type: type, content: content)
        }

        public static func file(url: URL) throws -> FormValue {
            let content = try Data(contentsOf: url)

            guard let type = try url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                throw BlueprintError.unknown
            }
            return try file(filename: url.lastPathComponent, type: type, content: content)
        }
    }

    public let contentType: String
    public let content: [String: FormValue]
    public let boundary: String

    public init(content: [String: FormValue]) {
        boundary = "BOUNDARY_\(String.random(count: 8, of: "abcdefghijklmnopqrstuvwyz"))"
        contentType = "multipart/form-data; charset=utf-8; boundary=\(boundary)"
        self.content = content
    }

    public func toData() throws -> some DataProtocol {
        // https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types#multipartform-data
        let chunks = content.map { name, value in
            value.data(name)
        }
        return Data([
            Data("--\(boundary)\r\n".utf8),
            Data(chunks.joined(separator: Data("--\(boundary)\r\n".utf8))),
            Data("--\(boundary)--\r\n".utf8),
        ].joined())
    }
}
