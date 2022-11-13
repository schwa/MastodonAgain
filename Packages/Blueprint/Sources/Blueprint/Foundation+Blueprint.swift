import Foundation

// TODO: Put this somewhere better.
internal func resolve(parameters: [String: Parameter], values: [String: String]) throws -> [String: String] {
    try Dictionary(uniqueKeysWithValues: parameters.compactMap { key, value in
        switch value {
        case .required(let expression):
            let expression = try expression.resolve(values)
            return (key, try Expression(expression).string)
        case .optional(let expression):
            if expression.canResolve(values) == false {
                return nil
            }
            else {
                let expression = try expression.resolve(values)
                return (key, try Expression(expression).string)
            }
        }
    })
}

public extension URLRequest {
    init <ResultType>(url: URL, request: Blueprint<ResultType>, variables: [String: String]) throws {
        let queryItems = try resolve(parameters: request.headers, values: variables).map { name, value in
            URLQueryItem(name: name, value: value)
        }
        let path = try Expression(request.path.resolve(variables)).string
        let url = url.appending(path: path).appending(queryItems: queryItems)
        self = URLRequest(url: url)
        httpMethod = request.method.rawValue
        let headers = try resolve(parameters: request.headers, values: variables)
        for (name, value) in headers {
            setValue(value, forHTTPHeaderField: name)
        }
        if let body = request.body {
            setValue(body.contentType, forHTTPHeaderField: "Content-Type")
            httpBody = Data(try body.toData())
        }
    }
}

public extension Blueprint {
    func handleResponse(data: Data, response: URLResponse) throws -> ResultType {
        guard let response = response as? HTTPURLResponse else {
            fatalError("Could not cast URLResponse to HTTPURLResponse.")
        }
        // TODO: Fix the generics type system so this as? cast isn't necessary.
        guard let value = try expectedResponse.handle(data: data, response: response) as? ResultType else {
            fatalError("Could not cast response to correct type.")
        }
        return value
    }
}
