import Blueprint
import Everything
import Foundation
import RegexBuilder
import SwiftUI

// swiftlint:disable file_length

public enum MastodonError: Error {
    case authorisationFailure
    case generic(String)
}

public extension Token {
    var headers: [String: String] {
        ["Authorization": "Bearer \(accessToken)"]
    }
}

public extension URLRequest {
    @available(*, deprecated, message: "Use Blueprints")
    static func post(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        return request
    }

    @available(*, deprecated, message: "Use Blueprints")
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

@available(*, deprecated, message: "Use Blueprints")
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

public extension URLRequest {
    @available(*, deprecated, message: "Use Blueprints")
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
    @available(*, deprecated, message: "Use Blueprints")
    func string(for request: URLRequest) async throws -> (String, URLResponse) {
        let (data, response) = try await data(for: request)
        let string = String(data: data, encoding: .utf8)!
        return (string, response)
    }

    @available(*, deprecated, message: "Use Blueprints")
    func json<T>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder(), for request: URLRequest) async throws -> (T, URLResponse) where T: Decodable {
        let (data, response) = try await data(for: request)
        let json = try decoder.decode(type, from: data)
        return (json, response)
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
    @available(*, deprecated, message: "Use Blueprints")
    func validatedData(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            fatalError("Expected response to be a HTTPURLResponse. Boy was I wrong.")
        }
        switch httpResponse.statusCode {
        case 200 ..< 299:
            return (data, httpResponse)
        //    case 401:
        //        throw HTTPError(statusCode: .init(response.statusCode))
        default:
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

@available(*, deprecated, message: "Remove")
public enum FormValue {
    case value(_ name: String, _ value: String)
    case file(_ name: String, _ filename: String, _ mimeType: String, _ data: Data)
}

@available(*, deprecated, message: "Remove")
public extension Sequence<FormValue> {
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
            Data("--\(boundary)--\r\n".utf8),
        ].joined())
    }
}

public extension URLRequest {
    @available(*, deprecated, message: "Remove")
    func form(_ form: [String: String]) -> URLRequest {
        var copy = self
        copy.httpMethod = "POST"
        copy.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        copy.httpBody = form.formEncoded
        let data = form.formEncoded
        copy.httpBody = data
        return copy
    }

    @available(*, deprecated, message: "Remove")
    func multipartForm(_ values: [FormValue]) -> URLRequest {
        var copy = self
        copy.httpMethod = "POST"
        let boundary = "__X_BOUNDARY__"
        copy.setValue("multipart/form-data; charset=utf-8; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
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

public struct PlaceholderCodable: Codable, Sendable, Equatable {
}

public struct FunHash<Content>: Hashable where Content: Hashable {
    let rawValue: String

    public init(_ content: Content) {
        let adjectives = ["abrupt", "acidic", "adorable", "adventurous", "aggressive", "agitated", "alert", "aloof", "bored", "brave", "bright", "colossal", "condescending", "confused", "cooperative", "corny", "costly", "courageous", "cruel", "despicable", "determined", "dilapidated", "diminutive", "distressed", "disturbed", "dizzy", "exasperated", "excited", "exhilarated", "extensive", "exuberant", "frothy", "frustrating", "funny", "fuzzy", "gaudy", "graceful", "greasy", "grieving", "gritty", "grotesque", "grubby", "grumpy", "handsome", "happy", "hollow", "hungry", "hurt", "icy", "ideal", "immense", "impressionable", "intrigued", "irate", "foolish", "frantic", "fresh", "friendly", "frightened", "frothy", "frustrating", "glorious", "gorgeous", "grubby", "happy", "harebrained", "healthy", "helpful", "helpless", "high", "hollow", "homely", "large", "lazy", "livid", "lonely", "loose", "lovely", "lucky", "mysterious", "narrow", "nasty", "outrageous", "panicky", "perfect", "perplexed", "quizzical", "teeny", "tender", "tense", "terrible", "tricky", "troubled", "unsightly", "upset", "wicked", "yummy", "zany", "zealous", "zippy"]

        let cities = ["Paris", "London", "Bangkok", "Singapore", "New York", "Kuala Lumpur", "Hong Kong", "Dubai", "Istanbul", "Rome", "Shanghai", "Los Angeles", "Las Vegas", "Miami", "Toronto", "Barcelona", "Dublin", "Amsterdam", "Moscow", "Cairo", "Prague", "Vienna", "Madrid", "San Francisco", "Vancouver", "Budapest", "Rio de Janeiro", "Berlin", "Tokyo", "Mexico City", "Buenos Aires", "St. Petersburg", "Seoul", "Athens", "Jerusalem", "Seattle", "Delhi", "Sydney", "Mumbai", "Munich", "Venice", "Florence", "Beijing", "Cape Town", "Washington D.C.", "Montreal", "Atlanta", "Boston", "Philadelphia", "Chicago", "San Diego", "Stockholm", "Cancún", "Warsaw", "Sharm el-Sheikh", "Dallas", "Hồ Chí Minh", "Milan", "Oslo", "Libson", "Punta Cana", "Johannesburg", "Antalya", "Mecca", "Macau", "Pattaya", "Guangzhou", "Kiev", "Shenzhen", "Bucharest", "Taipei", "Orlando", "Brussels", "Chennai", "Marrakesh", "Phuket", "Edirne", "Bali", "Copenhagen", "São Paulo", "Agra", "Varna", "Riyadh", "Jakarta", "Auckland", "Honolulu", "Edinburgh", "Wellington", "New Orleans", "Petra", "Melbourne", "Luxor", "Hà Nội", "Manila", "Houston", "Phnom Penh", "Zürich", "Lima", "Santiago", "Bogotá"]

        var rng = SplitMix64(s: UInt64(bitPattern: Int64(content.hashValue)))
        rawValue = "\(adjectives.randomElement(using: &rng)!)-\(cities.randomElement(using: &rng)!)-\(Int.random(in: 1 ... 10, using: &rng))"
    }
}

extension FunHash: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

// MARK: -

public extension JSONDecoder {
    static var mastodonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: string) {
                return date
            }
            formatter.formatOptions.remove(.withFullTime)
            if let date = formatter.date(from: string) {
                return date
            }
            fatalError("Failed to decode date \(string)")
        })
        return decoder
    }
}

public extension Locale {
    var topLevelIdentifier: String {
        String(identifier.prefix(upTo: identifier.firstIndex(of: "_") ?? identifier.endIndex))
    }

    static var availableTopLevelIdentifiers: [String] {
        Locale.availableIdentifiers.filter({ !$0.contains("_") })
    }
}

// TODO: Use a ImageSpecifier instead.
extension Image: @unchecked Sendable {
}

public extension URLCache {
    static let imageCache = URLCache(memoryCapacity: 512 * 1000 * 1000, diskCapacity: 10 * 1000 * 1000 * 1000)
}

func standardResponse<T>(_ type: T.Type) -> some ResultGenerator where T: Decodable {
    IfStatus(200) { data, response in
        print("X-RateLimit-Remaining: \(String(describing: response.value(forHTTPHeaderField: "X-RateLimit-Remaining")))")
        return try JSONDecoder.mastodonDecoder.decode(T.self, from: data)
    }
}

public extension Account {
    var name: String {
        (displayName.isEmpty ? username ?? acct : displayName)
    }

    var fullUsername: String {
        // TODO:
        acct
    }
}
