import Everything
import Foundation

public protocol Response {
    associatedtype ResponseContent: Response
    associatedtype Result

    @ResponseBuilder
    var response: ResponseContent { get }
}

// extension Response where ResponseContent: ResultGenerator {
//    //typealias Result = ResultGenerator.Result
// }

extension Never: Response {
    public typealias ResponseContent = Never
    public typealias Result = Never

    public var response: Never {
        // swiftlint:disable:next implicit_return
        return uncallable() // NOTE: Return is necessary alas to short circule the @resultBuilder
    }
}

public extension Response where ResponseContent == Never {
    var response: Never {
        uncallable()
    }
}

@resultBuilder
public enum ResponseBuilder {
    public static func buildBlock<Component>(_ components: (Component)?...) -> CompositeResponse<Component.Result> where Component: ResultGenerator {
        CompositeResponse(components: components.compactMap { $0 })
    }
}

// MARK: -

public struct CompositeResponse<Result> {
    public let components: [any ResultGenerator]
}

extension CompositeResponse: Response {
    public typealias ResponseContent = Never
}

extension CompositeResponse: ResultGenerator {
    public func canProcess(data: Data, urlResponse: HTTPURLResponse) -> Bool {
        components.contains(where: { $0.canProcess(data: data, urlResponse: urlResponse) == true })
    }

    public func process(data: Data, urlResponse: HTTPURLResponse) throws -> Result {
        guard let component = components.first(where: { $0.canProcess(data: data, urlResponse: urlResponse) == true }) else {
            throw BlueprintError.generic("Cannot handle \(urlResponse)")
        }
        guard let result = try component.process(data: data, urlResponse: urlResponse) as? Result else {
            fatalError("Could not convert result to correct type.")
        }
        return result
    }
}

// MARK: -

// TODO: Rename this. Name is horrible.
public protocol ResultGenerator {
    associatedtype Result

    func canProcess(data: Data, urlResponse: HTTPURLResponse) -> Bool
    func process(data: Data, urlResponse: HTTPURLResponse) throws -> Result
}

public struct IfStatus<Result> {
    let codes: Set<Int>
    let block: (_ data: Data, _ urlResponse: HTTPURLResponse) throws -> Result

    public init(_ code: Int, block: @escaping (_ data: Data, _ urlResponse: HTTPURLResponse) throws -> Result) {
        codes = [code]
        self.block = block
    }
}

extension IfStatus: Response {
    public typealias ResponseContent = Never
}

extension IfStatus: ResultGenerator {
    public func canProcess(data: Data, urlResponse: HTTPURLResponse) -> Bool {
        codes.contains(urlResponse.statusCode)
    }

    public func process(data: Data, urlResponse: HTTPURLResponse) throws -> Result {
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

extension ConstantResponse: Response {
    public typealias ResponseContent = Never
}

extension ConstantResponse: ResultGenerator {
    public func canProcess(data: Data, urlResponse: HTTPURLResponse) -> Bool {
        true
    }

    public func process(data: Data, urlResponse: HTTPURLResponse) throws -> Result {
        value
    }
}

// MARK: -

enum Enum1<C1> {
    case c1(C1)
}
