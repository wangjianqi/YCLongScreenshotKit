import XCTest
@testable import YCLongScreenshotKit

final class YCScrollSlicePlannerTests: XCTestCase {
    func testNonUniformOffsetsRemoveOverlap() throws {
        let slices = try YCScrollSlicePlanner.makeSlices(
            offsets: [0, 475, 925], viewportHeight: 500
        )
        XCTAssertEqual(slices.count, 3)
        XCTAssertEqual(slices[0].sourceTop, 0, accuracy: 0.001)
        XCTAssertEqual(slices[1].sourceTop, 25, accuracy: 0.001)
        XCTAssertEqual(slices[1].destinationTop, 500, accuracy: 0.001)
        XCTAssertEqual(slices[2].sourceTop, 50, accuracy: 0.001)
        XCTAssertEqual(slices[2].destinationTop + slices[2].height, 1425, accuracy: 0.001)
    }

    func testAbsoluteScrollOriginIsIrrelevant() throws {
        let slices = try YCScrollSlicePlanner.makeSlices(
            offsets: [-56, 344, 744], viewportHeight: 450
        )
        XCTAssertEqual(slices[0].destinationTop, 0, accuracy: 0.001)
        XCTAssertEqual(slices[1].destinationTop, 450, accuracy: 0.001)
    }

    func testGapThrowsRatherThanSilentlyMissingRows() {
        XCTAssertThrowsError(try YCScrollSlicePlanner.makeSlices(
            offsets: [0, 700], viewportHeight: 500
        ))
    }

    func testEmptyThrows() {
        XCTAssertThrowsError(try YCScrollSlicePlanner.makeSlices(
            offsets: [], viewportHeight: 500
        ))
    }

    func testDuplicateOffsetsAreIgnored() throws {
        let slices = try YCScrollSlicePlanner.makeSlices(
            offsets: [0, 0, 300], viewportHeight: 500
        )
        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices[1].frameIndex, 2)
    }
}
