import XCTest
import Blueprint

public enum MastodonAPI {
    struct Application: Codable, Hashable {
    }

    struct Error: Swift.Error, Codable, Hashable {
    }

    enum Apps {
        struct Verify: Request, Response {
            let baseURL: URL
            let token: String

            var request: some Request {
                Method.get
                baseURL
                URLPath("/api/v1/apps/verify_credentials")
                Header(name: "Authorization", value: "Bearer \(token)")
            }

            var response: some Response {
                IfStatus(200) { data, _ in
                    try JSONDecoder().decode(Application.self, from: data)
                }
            }
        }
    }
}

// MARK: -

class MyTests: XCTestCase {
    func test1() throws {
        let verify = MastodonAPI.Apps.Verify(baseURL: "http://mastodon.example", token: "12345")
        let urlRequest = try URLRequest(verify)
        XCTAssertEqual(urlRequest.url, URL("http://mastodon.example/api/v1/apps/verify_credentials"))
        XCTAssertEqual(urlRequest.httpMethod, "GET")
        XCTAssertEqual(urlRequest.allHTTPHeaderFields, ["Authorization": "Bearer 12345"])

        let urlResponse = HTTPURLResponse(url: URL("http://mastodon.example/api/v1/apps/verify_credentials"), statusCode: 200, httpVersion: "1.0", headerFields: ["Content-Type": "application/json"])!
        let data = try JSONEncoder().encode(MastodonAPI.Application())
        let result = try verify.response.process(data: data, urlResponse: urlResponse)
        print(type(of: result))
        XCTAssertEqual(result as! MastodonAPI.Application, MastodonAPI.Application())

        let result2 = try test(verify, data: data, urlResponse: urlResponse)
        print(result2)
    }
}

func test <R>(_ requestResponse: R, data: Data, urlResponse: URLResponse) throws -> R.ResponseContent.Result where R: Request & Response {
    let urlRequest = try URLRequest(requestResponse)
    let result = try requestResponse.response.process(data: data, urlResponse: urlResponse)
    return result
}
