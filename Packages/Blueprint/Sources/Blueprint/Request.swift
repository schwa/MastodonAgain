import Foundation

public protocol Request {
    associatedtype RequestContent: Request

    func apply(request: inout PartialRequest) throws

    @RequestBuilder
    var request: RequestContent { get }
}

public extension Request {
    func apply(request: inout PartialRequest) throws {
        try self.request.apply(request: &request)
    }
}

public extension Request where RequestContent == Never {
    var request: Never {
        fatalError("This should never be called.")
    }
}

@resultBuilder
public enum RequestBuilder {
    public static func buildBlock(_ components: (any Request)?...) -> CompositeRequest {
        CompositeRequest(children: components.compactMap({ $0 }))
    }
}

public struct CompositeRequest: Request {
    public typealias RequestContent = Never

    public func apply(request: inout PartialRequest) throws {
        for child in children {
            try child.apply(request: &request)
        }
    }

    var children: [any Request]
}

extension Never: Request {
    public typealias RequestContent = Never
}

extension URL: Request {
    public func apply(request: inout PartialRequest) throws {
        request.url = self
    }

    public typealias RequestContent = Never
}

extension Method: Request {
    public func apply(request: inout PartialRequest) throws {
        request.method = self
    }

    public typealias RequestContent = Never
}

extension Header: Request {
    public func apply(request: inout PartialRequest) throws {
        request.headers.append(self)
    }

    public typealias RequestContent = Never
}

extension URLQueryItem: Request {
    public func apply(request: inout PartialRequest) throws {
        request.url?.append(queryItems: [self])
    }

    public typealias RequestContent = Never
}

extension URLPath: Request {
    public typealias RequestContent = Never

    public func apply(request: inout PartialRequest) throws {
        request.url?.append(path: rawValue)
    }
}
