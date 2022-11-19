@testable import Support
import XCTest

final class CompositeHashTests: XCTestCase {
    func testIdentical() throws {
        let lhs = CompositeHash([1, 2, 3])
        let rhs = CompositeHash([1, 2, 3])
        XCTAssertTrue(lhs == rhs)
        XCTAssertFalse(lhs > rhs)
        XCTAssertFalse(lhs < rhs)
        XCTAssertTrue(lhs <= rhs)
        XCTAssertTrue(lhs >= rhs)
    }

    func testShorter1() throws {
        let lhs = CompositeHash([1, 2])
        let rhs = CompositeHash([1, 2, 3])
        XCTAssertFalse(lhs == rhs)
        XCTAssertFalse(lhs > rhs)
        XCTAssertTrue(lhs < rhs)
        XCTAssertTrue(lhs <= rhs)
        XCTAssertFalse(lhs >= rhs)
    }

    func testShorter2() throws {
        let lhs = CompositeHash([1, 2, 3])
        let rhs = CompositeHash([1, 2])
        XCTAssertFalse(lhs == rhs)
        XCTAssertTrue(lhs > rhs)
        XCTAssertFalse(lhs < rhs)
        XCTAssertFalse(lhs <= rhs)
        XCTAssertTrue(lhs >= rhs)
    }

    func testDiffering1() throws {
        let lhs = CompositeHash([1, 2, 3])
        let rhs = CompositeHash([1, 2, 4])
        XCTAssertFalse(lhs == rhs)
        XCTAssertFalse(lhs > rhs)
        XCTAssertTrue(lhs < rhs)
        XCTAssertTrue(lhs <= rhs)
        XCTAssertFalse(lhs >= rhs)
    }

    func testDiffering2() throws {
        let lhs = CompositeHash([1, 2, 4])
        let rhs = CompositeHash([1, 2, 3])
        XCTAssertFalse(lhs == rhs)
        XCTAssertTrue(lhs > rhs)
        XCTAssertFalse(lhs < rhs)
        XCTAssertFalse(lhs <= rhs)
        XCTAssertTrue(lhs >= rhs)
    }
}
