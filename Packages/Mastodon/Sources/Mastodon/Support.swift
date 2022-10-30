import Foundation
import RegexBuilder

public enum MastodonError {
    case authorisationFailure
}

public extension Token {
    var headers: [String: String] {
        return ["Authorization":"Bearer \(accessToken)"]
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
        original.merge(headers) { lhs, rhs in
            rhs
        }
        copy.allHTTPHeaderFields = original
        return copy
    }
}


public struct Dated <Content> {

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
        fatalError()
    }

    switch response.statusCode {
    case 200..<299:
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
        return lhs.rawValue < rhs.rawValue
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


public extension Dictionary where Key == String, Value == String {
    var formEncoded: Data {
        //             client_name=Test+Application&redirect_uris=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&scopes=read+write+follow+push&website=https%3A%2F%2Fmyapp.example

        let bodyString = map { (key, value) in
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
        return lhs.union(rhs)
    }
}

public extension URLRequest {
    init(url: URL, formParameters form: Dictionary<String, String>) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = form.formEncoded
        self = request
    }
}

public enum Uncertain <Known, Unknown> where Known: RawRepresentable, Unknown == Known.RawValue {
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
        return statusCode.description
    }
}


public extension URLSession {

    func string(for request: URLRequest) async throws -> (String, URLResponse) {
        let (data, response) = try await data(for: request)
        let string = String(data: data, encoding: .utf8)!
        return (string, response)
    }


    func json <T>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder(), for request: URLRequest) async throws -> (T, URLResponse) where T: Decodable {
        let (data, response) = try await data(for: request)
        let json = try decoder.decode(type, from: data)
        return (json, response)
    }
}

public extension Status {
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
        if let width = width, let height = height {
            return CGSize(width: width, height: height)
        }
        else if let width = width, let aspect = aspect, aspect > 0 {
            return CGSize(width: width, height: width * aspect)
        }
        else if let height = height, let aspect = aspect, aspect > 0 {
            return CGSize(width: height / aspect, height: height)
        }
        else if let size = size {
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
