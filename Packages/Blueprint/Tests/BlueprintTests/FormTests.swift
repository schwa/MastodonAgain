import Blueprint
import XCTest

class FormTests: XCTestCase {
    func test1() throws {
        let form = Form(multipartBoundary: "xyzzy") {
            FormParameter(name: "description", value: "Guess.")
            FormParameter(name: "file", filename: "HelloWorld.txt", mimetype: "text/plain") {
                Data("Hello world".utf8)
            }
        }

        var request = PartialRequest()
        try form.apply(request: &request)

        let result = String(data: request.data, encoding: .utf8)!
        let expectedResult = """
        GET / HTTP/1.1
        Content-Type: multipart/form-data; charset=utf-8; boundary=xyzzy

        --xyzzy
        Content-Disposition: form-data; name="description"

        Guess.
        --xyzzy
        Content-Disposition: form-data; name="file"; filename="HelloWorld.txt"
        Content-Type: text/plain

        Hello world
        --xyzzy--

        """
        .replacing("\n", with: "\r\n")

        print("###########################################")
        print(result)
        print("###########################################")
        print(expectedResult)
        print("###########################################")

        XCTAssertEqual(result, expectedResult)
    }
}
