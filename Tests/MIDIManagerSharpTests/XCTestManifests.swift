import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(MIDIManagerSharpTests.allTests),
    ]
}
#endif
