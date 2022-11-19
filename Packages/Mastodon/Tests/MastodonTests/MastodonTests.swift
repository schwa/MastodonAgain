@testable import Mastodon
import XCTest

final class MastodonTests: XCTestCase {
    func testMultipartForm() throws {
        let expected = """
        -----------------------------8721656041911415653955004498
        Content-Disposition: form-data; name="myTextField"

        Test
        -----------------------------8721656041911415653955004498
        Content-Disposition: form-data; name="myCheckBox"

        on
        -----------------------------8721656041911415653955004498
        Content-Disposition: form-data; name="myFile"; filename="test.txt"
        Content-Type: text/plain

        Simple file.
        -----------------------------8721656041911415653955004498--
        """
        .components(separatedBy: .newlines).joined(separator: "\r\n")

        let values: [FormValue] = [
            .value("myTextField", "Test"),
            .value("myCheckBox", "on"),
            .file("myFile", "test.txt", "text/plain", Data("Simple file.".utf8))
        ]
        let data = values.data(boundary: "---------------------------8721656041911415653955004498")
        try Data(expected.utf8).write(to: URL(filePath: "/tmp/expected.txt"))

        XCTAssertEqual(Data(expected.utf8), data)
    }

    func testStasusDecoding() throws {
        let url = Bundle.module.url(forResource: "page", withExtension: "json")!
        let data = try Data(contentsOf: url)
        XCTAssertNoThrow(try JSONDecoder.mastodonDecoder.decode([Status].self, from: data))
    }
}
