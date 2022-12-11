import Foundation

public extension PartialRequest {
    init(_ request: some Request) throws {
        self.init()
        try request.apply(request: &self)
    }
}

public extension URLRequest {
    init(_ request: some Request) throws {
        let partialRequest = try PartialRequest(request)
        try self.init(partialRequest)
    }
}

public extension URLSession {
    // TODO: This should take a request and response - and not a resultGenerator
    func perform<R2>(request: some Request, resultGenerator: R2) async throws -> R2.Result where R2: ResultGenerator {
        var partialRequest = PartialRequest()
        try request.apply(request: &partialRequest)
        let urlRequest = try URLRequest(partialRequest)
        let (data, urlResponse) = try await data(for: urlRequest)

        guard let urlResponse = urlResponse as? HTTPURLResponse else {
            fatalError("Failed to get a HTTPURLResponse. Did we try to talk to a gopher server?")
        }
        let result = try resultGenerator.process(data: data, urlResponse: urlResponse)
        return result
    }
}
