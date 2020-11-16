import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(struct_vapor_endpointsTests.allTests),
    ]
}
#endif
