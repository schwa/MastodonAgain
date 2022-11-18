import Everything
import Foundation

public protocol Response {
    associatedtype ResponseContent: Response
    associatedtype Result

    @ResponseBuilder
    var response: ResponseContent { get }

    func canProcess(data: Data, urlResponse: URLResponse) -> Bool
    func process(data: Data, urlResponse: URLResponse) throws -> Result
}

public extension Response {
    func canProcess(data: Data, urlResponse: URLResponse) -> Bool {
        response.canProcess(data: data, urlResponse: urlResponse)
    }
}

public extension Response where ResponseContent.Result == Result {
    func process(data: Data, urlResponse: URLResponse) throws -> Result {
        try response.process(data: data, urlResponse: urlResponse)
    }
}

extension Never: Response {
    public typealias ResponseContent = Never
    public typealias Result = Never

    public var response: Never {
        return uncallable() // Return is necessary alas
    }

    public func canProcess(data: Data, urlResponse: URLResponse) -> Bool {
        uncallable()
    }

    public func process(data: Data, urlResponse: URLResponse) throws -> Never {
        uncallable()
    }
}

public extension Response where ResponseContent == Never {
    var response: Never {
        uncallable()
    }
}

public extension Response where Result == Never {
    func canProcess(data: Data, urlResponse: URLResponse) -> Bool {
        uncallable()
    }

    func process(data: Data, urlResponse: URLResponse) throws -> Never {
        uncallable()
    }
}

@resultBuilder
public enum ResponseBuilder {
    public static func buildBlock<C>(_ components: C?...) -> CompositeResponse<C> where C: Response {
        CompositeResponse(components: components.compactMap { $0 })
    }
}

// MARK: -

public struct CompositeResponse<C> where C: Response {
    public typealias Result = C.Result
    public let components: [C]
}

extension CompositeResponse: Response {
    public typealias ResponseContent = Never

    public func canProcess(data: Data, urlResponse: URLResponse) -> Bool {
        components.contains(where: { $0.canProcess(data: data, urlResponse: urlResponse) })
    }

    public func process(data: Data, urlResponse: URLResponse) throws -> Result {
        guard let child = components.first(where: { $0.canProcess(data: data, urlResponse: urlResponse) }) else {
            throw BlueprintError.generic("Unhandled response \(urlResponse).")
        }
        return try child.process(data: data, urlResponse: urlResponse)
    }
}

// MARK: -

public struct IfStatus<Result> {
    let codes: Set<Int>
    let block: (_ data: Data, _ urlResponse: URLResponse) throws -> Result

    public init(_ code: Int, block: @escaping (_ data: Data, _ urlResponse: URLResponse) throws -> Result) {
        codes = [code]
        self.block = block
    }
}

extension IfStatus: Response {
    public typealias ResponseContent = Never

    public func canProcess(data: Data, urlResponse: URLResponse) -> Bool {
        guard let urlResponse = urlResponse as? HTTPURLResponse else {
            fatalError() // TODO: throw
        }
        return codes.contains(urlResponse.statusCode)
    }

    public func process(data: Data, urlResponse: URLResponse) throws -> Result {
        try block(data, urlResponse)
    }
}

// MARK: -

public struct ConstantResponse<Result> {
    let value: Result

    public init(_ value: Result) {
        self.value = value
    }
}

// extension ConstantResponse: Response {
//    public typealias ResponseContent = Never
//
//    public func canProcess(data: Data, urlResponse: URLResponse) throws -> Bool {
//        return true
//    }
//
//    public func process(data: Data, urlResponse: URLResponse) throws -> Result {
//        return value
//    }
// }
