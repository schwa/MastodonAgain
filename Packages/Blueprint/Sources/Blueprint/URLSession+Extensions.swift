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
    func perform <R>(_ requestResponse: R) async throws -> R.ResponseContent.Result where R: Request, R: Response {
        var partialRequest = PartialRequest()
        try requestResponse.apply(request: &partialRequest)
        let urlRequest = try URLRequest(partialRequest)
        let (data, urlResponse) = try await data(for: urlRequest)
        let result = try requestResponse.response.process(data: data, urlResponse: urlResponse)
        return result
    }
}
