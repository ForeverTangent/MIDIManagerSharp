import XCTest
@testable import MIDIManagerSharp

final class MIDIManagerSharpTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(MIDIManagerSharp().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
