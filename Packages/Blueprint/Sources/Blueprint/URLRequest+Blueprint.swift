import Foundation

public extension URLRequest {
    init(url: URL, request: Request, variables: [String: String]) throws {
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
