import Foundation

public extension URLRequest {
    init <ResultType>(url: URL, request: Blueprint<ResultType>, variables: [String: String]) throws {
        let request = try request.resolve(variables)
        self.init(url: url.appending(path: try request.path.string))
        httpMethod = request.method.rawValue
        for (name, parameter) in request.headers {
            setValue(try parameter.string, forHTTPHeaderField: name)
        }
        if let body = request.body {
            setValue(body.contentType, forHTTPHeaderField: "Content-Type")
            httpBody = Data(try body.toData())
        }
    }
}

