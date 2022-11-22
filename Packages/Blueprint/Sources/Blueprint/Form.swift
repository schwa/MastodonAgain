import Everything
import Foundation
import UniformTypeIdentifiers

public struct Form {
    var contentType: String?
    var multipartBoundary: String?
    var parameters: [FormParameter]

    public init(contentType: String? = nil, multipartBoundary: String? = nil, @FormBuilder _ parameters: () -> [FormParameter]) {
        self.contentType = contentType
        self.multipartBoundary = multipartBoundary
        self.parameters = parameters()
    }
}

// MARK: -

public struct FormParameter: Sendable {
    public var name: String
    public enum Value: Sendable {
        case string(value: String?)
        case file(filename: String, mimetype: String?, content: @Sendable () throws -> Data)
    }
    public var value: Value

    public init(name: String, value: String? = nil) {
        self.name = name
        self.value = .string(value: value)
    }

    public init(name: String, filename: String, mimetype: String?, content: @escaping @Sendable () throws -> Data) {
        self.name = name
        self.value = .file(filename: filename, mimetype: mimetype, content: content)
    }

    public init(name: String, url: URL) {
        self.name = name
        let filename = url.lastPathComponent
        var mimetype: String?
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            mimetype = contentType.preferredMIMEType
        }
        self.value = .file(filename: filename, mimetype: mimetype) {
            try Data(contentsOf: url)
        }
    }
}

// MARK: -

extension Form: Request {
    var isMultipart: Bool {
        parameters.contains {
            if case .file = $0.value {
                return true
            }
            else {
                return false
            }
        }
    }

    public func simpleFormApply(request: inout PartialRequest) throws {
        let contentType = contentType ?? "application/x-www-form-urlencoded; charset=utf-8"
        request.headers.append(Header(name: "Content-Type", value: contentType))
        request.body = Data(parameters.map { parameter in
            let name = parameter.name.formEncoded
            guard case let .string(value) = parameter.value else {
                fatalError("Cannot encode a file in a simple form")
            }
            return "\(name)=\(value?.formEncoded ?? "")"
        }
        .joined(separator: "&")
        .utf8)
    }

    public func multipartFormApply(request: inout PartialRequest) throws {
        // https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types#multipartform-data
        let boundary = multipartBoundary ?? "BOUNDARY_\(String.random(count: 8, of: "abcdefghijklmnopqrstuvwyz"))"
        let contentType = contentType ?? "multipart/form-data; charset=utf-8; boundary=\(boundary)"
        request.headers.append(Header(name: "Content-Type", value: contentType))

        let parts = try parameters.map { parameter in
            switch parameter.value {
            case .string(value: let value):
                let chunks: [Chunk] = [
                    "Content-Disposition: form-data; name=\"\(parameter.name.formEncoded)\"",
                    "",
                    .string(value?.formEncoded ?? ""),
                ]
                return chunks
            case .file(filename: let filename, mimetype: let mimetype, content: let content):
                let chunks = [
                    "Content-Disposition: form-data; name=\"\(parameter.name.formEncoded)\"; filename=\"\(filename.formEncoded)\"",
                    mimetype.map { Chunk.string("Content-Type: \($0)") },
                    "",
                    .data(try content()),
                ]
                .compacted()
                return Array(chunks)
            }
        }
        let chunks: [Chunk] = [
            ["--\(boundary)"],
            Array(parts.joined(by: "--\(boundary)")),
            ["--\(boundary)--", ""],
        ]
        .flatMap { $0 }
        request.body = Data(chunks.interspersed(with: Chunk.string("\r\n")))
    }

    public func apply(request: inout PartialRequest) throws {
        if isMultipart {
            try multipartFormApply(request: &request)
        }
        else {
            try simpleFormApply(request: &request)
        }
    }
}

extension FormParameter: Request {
    public func apply(request: inout PartialRequest) throws {
        unimplemented()
    }
}

@resultBuilder
public enum FormBuilder {
    public static func buildBlock(_ components: FormParameter?...) -> [FormParameter] {
        components.compactMap { $0 }
    }
}

// MARK: -

extension String {
    static func random(count: Int, of set: String) -> String {
        String((0 ..< count).map({ _ in Character.random(in: set) }))
    }

    var formEncoded: String {
        replacing(" ", with: "+")
        .addingPercentEncoding(withAllowedCharacters: .alphanumerics + .punctuationCharacters + "+")!
    }

}

