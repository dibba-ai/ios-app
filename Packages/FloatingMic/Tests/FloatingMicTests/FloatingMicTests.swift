import XCTest
@testable import FloatingMic

final class FloatingMicTests: XCTestCase {
    @MainActor
    func testControllerInitialises() {
        let controller = FloatingMicController()
        XCTAssertNotNil(controller)
    }
}
