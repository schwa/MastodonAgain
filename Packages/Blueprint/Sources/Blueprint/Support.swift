import Everything
import Foundation

public enum BlueprintError: Error {
//    @available(*, deprecated, message: "Create better errors.")
    case unknown
//    @available(*, deprecated, message: "Create better errors.")
    case generic(String)
    case failedToResolveName(String)
}

extension CharacterSet: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = CharacterSet(charactersIn: value)
    }
}

extension CharacterSet {
    static func + (lhs: CharacterSet, rhs: CharacterSet) -> CharacterSet {
        lhs.union(rhs)
    }
}

extension Character {
    static func random(in set: String) -> Character {
        set.randomElement()!
    }
}

extension String {
    static func random(count: Int, of set: String) -> String {
        String((0 ..< count).map({ _ in Character.random(in: set) }))
    }
}

extension URL: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(string: value)!
    }
}

public struct URLPath: Hashable {
    public let rawValue: String

    public init(_ path: String) {
        rawValue = path
    }
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

public struct Form {
    let parameters: [FormParameter]

    public init(@FormBuilder _ parameters: () -> [FormParameter]) {
        self.parameters = parameters()
    }
}

extension Form: Request {
    public func apply(request: inout PartialRequest) throws {
        let bodyString = parameters.map { parameter in
            let key = parameter.name
                .replacing(" ", with: "+")
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics + .punctuationCharacters + "+")!
            let value = parameter.value ?? ""
                .replacing(" ", with: "+")
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics + .punctuationCharacters + "+")!
            return "\(key)=\(value)"
        }
            .joined(separator: "&")
        request.headers.append(.init(name: "Content-Type", value: "application/x-www-form-urlencoded; charset=utf-8"))
        request.body = bodyString.data(using: .utf8)!
    }
}

@resultBuilder
public enum FormBuilder {
    public static func buildBlock(_ components: FormParameter?...) -> [FormParameter] {
        components.compactMap { $0 }
    }
}

public struct FormParameter {
    public let name: String
    public let value: String?

    public init(name: String, value: String? = nil) {
        self.name = name
        self.value = value
    }
}

extension Array: Request where Element: Request {
    public func apply(request: inout PartialRequest) throws {
        try forEach { element in
            try element.apply(request: &request)
        }
    }
}

extension FormParameter: Request {
    public func apply(request: inout PartialRequest) throws {
        unimplemented()
    }
}
