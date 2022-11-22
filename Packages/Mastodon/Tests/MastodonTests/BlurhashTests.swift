import Foundation

@testable import Mastodon
import XCTest

final class BlurhashTests: XCTestCase {
    func testBad() throws {
        let hash = Blurhash("XXXXXXXXX")
        let image = try? hash.image(size: CGSize(128, 128))
        XCTAssertNil(image)
    }

    func testMaybeGood() throws {
        let hash = Blurhash("ULKczm*EQ.-D4.S~p0mm4oI.VspHRlWFrrRQ")
        let image = try? hash.image(size: CGSize(128, 128))
        XCTAssertNotNil(image)
    }
}
