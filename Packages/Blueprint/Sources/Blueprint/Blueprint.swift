import Foundation
import UniformTypeIdentifiers

public struct Blueprint <ResultType> {
    public enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    public enum Parameter {
        case required(Expression)
        case optional(Expression)
    }

    public var path: Expression
    public var method: Method
    public var headers: [String: Parameter]
    public var body: (any BodyProtocol)?
    public var expectedResponse: (any ResponseProtocol)?

    public init<Response>(path: Expression, method: Blueprint.Method, headers: [String: Blueprint.Parameter] = [:], body: (any BodyProtocol)? = nil, expectedResponse: Response) where Response: ResponseProtocol, Response.Value == ResultType {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
        self.expectedResponse = expectedResponse
    }

    public init(path: Expression, method: Blueprint.Method, headers: [String: Blueprint.Parameter] = [:], body: (any BodyProtocol)? = nil) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
        self.expectedResponse = nil
    }
}

public extension Blueprint {
    func handleResponse(data: Data, response: URLResponse) throws -> ResultType {
        guard let expectedResponse else {
            fatalError()
        }
        guard let response = response as? HTTPURLResponse else {
            fatalError()
        }
        // TODO: Fix the generics type system so this as? cast isn't necessary.
        guard let value = try expectedResponse.handle(data: data, response: response) as? ResultType else {
            fatalError()
        }
        return value
    }
}

public extension Blueprint {
    func resolve(_ variables: [String: String]) throws -> Self {
        var copy = self
        copy.path = Expression(try path.resolve(variables))
        copy.headers = try Dictionary(uniqueKeysWithValues: headers.compactMap { key, value in
            switch value {
            case .required(let expression):
                let expression = try expression.resolve(variables)
                return (key, .required(Expression(expression)))
            case .optional(let expression):
                if expression.canResolve(variables) == false {
                    return nil
                }
                else {
                    let expression = try expression.resolve(variables)
                    return (key, .optional(Expression(expression)))
                }
            }
        })
        return copy
    }
}

public extension Blueprint.Parameter {
    var string: String {
        get throws {
            switch self {
            case .required(let expression):
                return try expression.string
            case .optional(let expression):
                return try expression.string
            }
        }
    }
}

// MARK: -

// TODO: -> RequestBodyProtocol
public protocol BodyProtocol {
    associatedtype Output: DataProtocol

    var contentType: String { get }
    func toData() throws -> Output
}

public struct JSONBody <Content>: BodyProtocol where Content: Codable {
    public let contentType = "application/json"
    public let content: Content
    public let encoder: JSONEncoder

    public init(content: Content, encoder: JSONEncoder = JSONEncoder()) {
        self.content = content
        self.encoder = encoder
    }

    public func toData() throws -> some DataProtocol {
        return try JSONEncoder().encode(content)
    }
}

public struct FormBody: BodyProtocol {
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

public struct MultipartForm: BodyProtocol {
    public struct FormValue {
        internal let data: (_ name: String) -> Data

        public init(data: @escaping (String) -> Data) {
            self.data = data
        }

        public static func value(_ value: String) -> FormValue {
            return FormValue { name in
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
            return FormValue { name in
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

public protocol ResponseProtocol {
    associatedtype Value
    func handle(data: Data, response: HTTPURLResponse) throws -> Value
}

public struct JSONDecoderResponse <T>: ResponseProtocol where T: Decodable {
    let decoder: JSONDecoder

    public init(decoder: JSONDecoder = .init()) {
        self.decoder = decoder
    }

    public func handle(data: Data, response: HTTPURLResponse) throws -> T {
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            throw BlueprintError.generic("No content type header")
        }
        // swiftlint:disable:next colon
        let pattern = #/^\s*(?<type>[^;\s]+)(?:\s*;\s*(?<q>.+))?\s*$/#
        guard let match = contentType.firstMatch(of: pattern) else {
            throw BlueprintError.generic("Could not match content-type: \(contentType)")
        }
        let (_, mimeType, q) = match.output
        // text/html; charset=utf-8
        switch mimeType {
        case "application/json", "text/json", "text/javascript":
            return try decoder.decode(T.self, from: data)
        default:
            throw BlueprintError.unknown
        }
    }
}
