import XCTest
@testable import MIDIManagerSharp

@available(iOS 10.0, *)
final class MIDIManagerSharpTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
		XCTAssertEqual(MIDIManager.subsystem, "MIDIManager")
		XCTAssertEqual(MIDIManager.category, "MIDI")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
