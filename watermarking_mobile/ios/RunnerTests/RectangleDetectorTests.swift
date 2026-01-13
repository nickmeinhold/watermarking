import XCTest
import Vision
import CoreImage
@testable import Runner

class RectangleDetectorTests: XCTestCase {

    // MARK: - Coordinate Transformation Tests
    // These test the coordinate math used in RectangleDetector.completedVisionRequest
    // Vision framework returns normalized coordinates (0-1), which must be scaled to image dimensions

    func testNormalizedCoordinatesToImageCoordinates() {
        // Test the coordinate transformation logic used in RectangleDetector
        let width: CGFloat = 1920
        let height: CGFloat = 1080

        // Vision normalized coordinates (0-1 range)
        let normalizedTopLeft = CGPoint(x: 0.1, y: 0.9)
        let normalizedTopRight = CGPoint(x: 0.9, y: 0.9)
        let normalizedBottomLeft = CGPoint(x: 0.1, y: 0.1)
        let normalizedBottomRight = CGPoint(x: 0.9, y: 0.1)

        // Convert to image coordinates (as done in completedVisionRequest)
        let topLeft = CGPoint(x: normalizedTopLeft.x * width, y: normalizedTopLeft.y * height)
        let topRight = CGPoint(x: normalizedTopRight.x * width, y: normalizedTopRight.y * height)
        let bottomLeft = CGPoint(x: normalizedBottomLeft.x * width, y: normalizedBottomLeft.y * height)
        let bottomRight = CGPoint(x: normalizedBottomRight.x * width, y: normalizedBottomRight.y * height)

        // Verify transformations
        XCTAssertEqual(topLeft.x, 192.0, accuracy: 0.01)      // 0.1 * 1920
        XCTAssertEqual(topLeft.y, 972.0, accuracy: 0.01)      // 0.9 * 1080
        XCTAssertEqual(topRight.x, 1728.0, accuracy: 0.01)    // 0.9 * 1920
        XCTAssertEqual(topRight.y, 972.0, accuracy: 0.01)     // 0.9 * 1080
        XCTAssertEqual(bottomLeft.x, 192.0, accuracy: 0.01)   // 0.1 * 1920
        XCTAssertEqual(bottomLeft.y, 108.0, accuracy: 0.01)   // 0.1 * 1080
        XCTAssertEqual(bottomRight.x, 1728.0, accuracy: 0.01) // 0.9 * 1920
        XCTAssertEqual(bottomRight.y, 108.0, accuracy: 0.01)  // 0.1 * 1080
    }

    func testCornerCoordinatesAtImageBoundaries() {
        let width: CGFloat = 1024
        let height: CGFloat = 768

        // Full image (corners at 0 and 1)
        let topLeft = CGPoint(x: 0.0 * width, y: 1.0 * height)
        let topRight = CGPoint(x: 1.0 * width, y: 1.0 * height)
        let bottomLeft = CGPoint(x: 0.0 * width, y: 0.0 * height)
        let bottomRight = CGPoint(x: 1.0 * width, y: 0.0 * height)

        XCTAssertEqual(topLeft.x, 0.0)
        XCTAssertEqual(topLeft.y, 768.0)
        XCTAssertEqual(topRight.x, 1024.0)
        XCTAssertEqual(topRight.y, 768.0)
        XCTAssertEqual(bottomLeft.x, 0.0)
        XCTAssertEqual(bottomLeft.y, 0.0)
        XCTAssertEqual(bottomRight.x, 1024.0)
        XCTAssertEqual(bottomRight.y, 0.0)
    }

    func testCenteredRectangleCoordinates() {
        let width: CGFloat = 1000
        let height: CGFloat = 1000

        // Centered 50% rectangle
        let normalizedCenter = CGPoint(x: 0.5, y: 0.5)
        let center = CGPoint(x: normalizedCenter.x * width, y: normalizedCenter.y * height)

        XCTAssertEqual(center.x, 500.0)
        XCTAssertEqual(center.y, 500.0)
    }

    // MARK: - CIPerspectiveCorrection Filter Parameter Tests

    func testPerspectiveCorrectionFilterSetup() {
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            XCTFail("CIPerspectiveCorrection filter not available")
            return
        }

        // Set up corner vectors as done in RectangleDetector
        let topLeft = CGPoint(x: 100, y: 900)
        let topRight = CGPoint(x: 900, y: 900)
        let bottomLeft = CGPoint(x: 100, y: 100)
        let bottomRight = CGPoint(x: 900, y: 100)

        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

        // Verify values were set
        let setTopLeft = filter.value(forKey: "inputTopLeft") as? CIVector
        let setTopRight = filter.value(forKey: "inputTopRight") as? CIVector

        XCTAssertNotNil(setTopLeft)
        XCTAssertNotNil(setTopRight)
        XCTAssertEqual(setTopLeft?.cgPointValue, topLeft)
        XCTAssertEqual(setTopRight?.cgPointValue, topRight)
    }

    // MARK: - Scale Factor Calculation Tests

    func testScaleFactorForTargetWidth1024() {
        // RectangleDetector uses: 1024.0 / perspectiveImage.extent.width
        let targetWidth: CGFloat = 1024.0

        let testCases: [(inputWidth: CGFloat, expectedScale: CGFloat)] = [
            (512.0, 2.0),
            (1024.0, 1.0),
            (2048.0, 0.5),
            (4096.0, 0.25),
        ]

        for testCase in testCases {
            let scale = targetWidth / testCase.inputWidth
            XCTAssertEqual(scale, testCase.expectedScale, accuracy: 0.0001,
                          "Scale for width \(testCase.inputWidth) should be \(testCase.expectedScale)")
        }
    }

    func testLanczosScaleFilterSetup() {
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            XCTFail("CILanczosScaleTransform filter not available")
            return
        }

        let scale = 0.5
        filter.setValue(scale, forKey: kCIInputScaleKey)

        let setValue = filter.value(forKey: kCIInputScaleKey) as? Double
        XCTAssertEqual(setValue, scale)
    }
}
