import Everything
import Foundation
import RegexBuilder

public enum MastodonError {
    case authorisationFailure
}

public extension Token {
    var headers: [String: String] {
        ["Authorization": "Bearer \(accessToken)"]
    }
}

public extension URLRequest {
    static func post(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        return request
    }

    func headers(_ headers: [String: String]) -> URLRequest {
        var copy = self
        var original = copy.allHTTPHeaderFields ?? [:]
        original.merge(headers) { _, rhs in
            rhs
        }
        copy.allHTTPHeaderFields = original
        return copy
    }
}

public struct Dated<Content> {
    public let content: Content
    public let date: Date

    public init(_ content: Content, date: Date = Date()) {
        self.content = content
        self.date = date
    }
}

extension Dated: Hashable where Content: Hashable {
}

extension Dated: Equatable where Content: Equatable {
}

extension Dated: Encodable where Content: Encodable {
}

extension Dated: Decodable where Content: Decodable {
}

public func validate<T>(_ item: (T, URLResponse)) throws -> (T, URLResponse) {
    guard let (result, response) = item as? (T, HTTPURLResponse) else {
        fatalError("Response is not a HTTPURLResponse")
    }

    switch response.statusCode {
    case 200 ..< 299:
        break
    //    case 401:
    //        throw HTTPError(statusCode: .init(response.statusCode))
    default:
        print(response)
        throw HTTPError(statusCode: .init(response.statusCode))
    }
    return (result, response)
}

public struct URLPath {
    let rawValue: String
}

extension URLPath: Hashable {
}

extension URLPath: Comparable {
    public static func < (lhs: URLPath, rhs: URLPath) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension URLPath: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        rawValue = value
    }
}

extension URLPath: ExpressibleByStringInterpolation {
    public init(stringInterpolation: DefaultStringInterpolation) {
        rawValue = stringInterpolation.description // TODO?????
    }
}

extension URLPath: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

public extension [String: String] {
    var formEncoded: Data {
        //             client_name=Test+Application&redirect_uris=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&scopes=read+write+follow+push&website=https%3A%2F%2Fmyapp.example

        let bodyString = map { key, value in
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

extension CharacterSet: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = CharacterSet(charactersIn: value)
    }
}

public extension CharacterSet {
    static func + (lhs: CharacterSet, rhs: CharacterSet) -> CharacterSet {
        lhs.union(rhs)
    }
}

public extension URLRequest {
    init(url: URL, formParameters form: [String: String]) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = form.formEncoded
        self = request
    }
}

public enum Uncertain<Known, Unknown> where Known: RawRepresentable, Unknown == Known.RawValue {
    case known(Known)
    case unknown(Unknown)

    public init(_ value: Known.RawValue) {
        if let value = Known(rawValue: value) {
            self = .known(value)
        }
        else {
            self = .unknown(value)
        }
    }

    public var rawValue: Known.RawValue {
        switch self {
        case .known(let value):
            return value.rawValue
        case .unknown(let value):
            return value
        }
    }
}

extension Uncertain: CustomStringConvertible {
    public var description: String {
        switch self {
        case .known(let value):
            return String(describing: value)
        case .unknown(let value):
            return String(describing: value)
        }
    }
}

public struct HTTPError: Error {
    public enum StatusCode: Int {
        case unauthorized = 401
    }

    public let statusCode: Uncertain<StatusCode, Int>
}

extension HTTPError: CustomStringConvertible {
    public var description: String {
        statusCode.description
    }
}

public extension URLSession {
    func string(for request: URLRequest) async throws -> (String, URLResponse) {
        let (data, response) = try await data(for: request)
        let string = String(data: data, encoding: .utf8)!
        return (string, response)
    }

    func json<T>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder(), for request: URLRequest) async throws -> (T, URLResponse) where T: Decodable {
        let (data, response) = try await data(for: request)
        let json = try decoder.decode(type, from: data)
        return (json, response)
    }
}

public extension StatusProtocol {
    var attributedContent: AttributedString {
        #if os(macOS)
            let header = #"<meta charset="UTF-8">"#
            let html = header + content
            let htmlData = html.data(using: .utf8)!
            let nsAttributedContent = NSAttributedString(html: htmlData, documentAttributes: nil)!
            var attributedContent = AttributedString(nsAttributedContent)
            var container = AttributeContainer()
            container[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = .body
            attributedContent.mergeAttributes(container, mergePolicy: .keepNew)
            // Remove trailing newline caused by <p>…</p>
            if !attributedContent.characters.isEmpty {
                attributedContent.characters.removeLast()
            }
            return attributedContent
        #elseif os(iOS)
            return AttributedString() // TODO: Placeholder
        #endif
    }
}

public extension MediaAttachment.Meta.Size {
    var cgSize: CGSize? {
        if let width, let height {
            return CGSize(width: width, height: height)
        }
        else if let width, let aspect, aspect > 0 {
            return CGSize(width: width, height: width * aspect)
        }
        else if let height, let aspect, aspect > 0 {
            return CGSize(width: height / aspect, height: height)
        }
        else if let size {
            let regex = Regex {
                Capture {
                    OneOrMore(.digit)
                }
                "x"
                Capture {
                    OneOrMore(.digit)
                }
            }
            guard let match = size.firstMatch(of: regex) else {
                return nil
            }
            let (_, width, height) = match.output
            guard let width = Double(width), let height = Double(height) else {
                return nil
            }
            return CGSize(width: width, height: height)
        }
        else {
            return nil
        }
    }
}

extension URLSession {
    func validatedData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        let httpResponse = response as! HTTPURLResponse
        switch httpResponse.statusCode {
        case 200 ..< 299:
            return (data, httpResponse)
            //    case 401:
            //        throw HTTPError(statusCode: .init(response.statusCode))
        default:
            print(response)
            throw HTTPError(statusCode: .init(httpResponse.statusCode))
        }
    }
}

func processLinks(string: String) throws -> [String: URL] {
    let pattern = #/<(.+?)>;\s*rel="(.+?)", ?/#

    let s = try string.matches(of: pattern).map { match in
        let (_, url, rel) = match.output
        return try (String(rel), URL(string: String(url)).safelyUnwrap(GeneralError.missingValue))
    }
    return Dictionary(uniqueKeysWithValues: s)
}

public enum FormValue {
    case value(_ name: String, _ value: String)
    case file(_ name: String, _ filename: String, _ mimeType: String, _ data: Data)
}

public extension Sequence where Element == FormValue {
    func data(boundary: String) -> Data {
        let chunks = map { value in
            switch value {
            case .value(let name, let value):
                let lines = [
                    "Content-Disposition: form-data; name=\"\(name)\"",
                    "",
                    value,
                    "",
                ]
                return Data(lines.joined(separator: "\r\n").utf8)
            case .file(let name, let filename, let mimetype, let data):
                let lines = [
                    "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"",
                    "Content-Type: \(mimetype)",
                    "",
                    "",
                ]
                let header = Data(lines.joined(separator: "\r\n").utf8)
                return header + data + Data("\r\n".utf8)
            }
        }
        return Data([
            Data("--\(boundary)\r\n".utf8),
            Data(chunks.joined(separator: Data("--\(boundary)\r\n".utf8))),
            Data("--\(boundary)--".utf8),
        ].joined())
    }
}

public extension URLRequest {
    func form(_ form: [String: String]) -> URLRequest {
        var copy = self
        copy.httpMethod = "POST"
        copy.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        copy.httpBody = form.formEncoded
        let data = form.formEncoded
        copy.httpBody = data
        return copy
    }

    func multipartForm(_ values: [FormValue]) -> URLRequest {
        var copy = self
        copy.httpMethod = "POST"
        let boundary = "__X_BOUNDARY__"
        copy.setValue("multipart/form-data; charset=utf-8; boundary=\(boundary)}", forHTTPHeaderField: "Content-Type")
        // https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types#multipartform-data
        copy.httpBody = values.data(boundary: boundary)
        return copy
    }
}

public func jsonTidy(data: Data) throws -> String {
    let json = try JSONSerialization.jsonObject(with: data)
    let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    return String(data: data, encoding: .utf8)!
}
