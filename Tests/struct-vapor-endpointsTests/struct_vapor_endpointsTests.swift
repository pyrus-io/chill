import XCTest
@testable import struct_vapor_endpoints

final class struct_vapor_endpointsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(struct_vapor_endpoints().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
