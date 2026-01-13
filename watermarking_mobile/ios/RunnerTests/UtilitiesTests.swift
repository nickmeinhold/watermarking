import XCTest
import CoreImage
import CoreML
import SceneKit
@testable import Runner

class UtilitiesTests: XCTestCase {

    // MARK: - CIImage.resize() Tests

    func testResizeImageToSmallerSize() {
        // Create a test CIImage with known dimensions
        let originalSize = CGSize(width: 100, height: 100)
        let ciImage = CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: originalSize))

        let targetSize = CGSize(width: 50, height: 50)
        guard let resizedImage = ciImage.resize(to: targetSize) else {
            XCTFail("resize returned nil")
            return
        }

        XCTAssertEqual(resizedImage.extent.size.width, targetSize.width, accuracy: 0.01)
        XCTAssertEqual(resizedImage.extent.size.height, targetSize.height, accuracy: 0.01)
    }

    func testResizeImageToLargerSize() {
        let originalSize = CGSize(width: 100, height: 100)
        let ciImage = CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: originalSize))

        let targetSize = CGSize(width: 200, height: 200)
        guard let resizedImage = ciImage.resize(to: targetSize) else {
            XCTFail("resize returned nil")
            return
        }

        XCTAssertEqual(resizedImage.extent.size.width, targetSize.width, accuracy: 0.01)
        XCTAssertEqual(resizedImage.extent.size.height, targetSize.height, accuracy: 0.01)
    }

    func testResizeImageWithDifferentAspectRatio() {
        let originalSize = CGSize(width: 100, height: 100)
        let ciImage = CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: originalSize))

        let targetSize = CGSize(width: 200, height: 100)
        guard let resizedImage = ciImage.resize(to: targetSize) else {
            XCTFail("resize returned nil")
            return
        }

        XCTAssertEqual(resizedImage.extent.size.width, targetSize.width, accuracy: 0.01)
        XCTAssertEqual(resizedImage.extent.size.height, targetSize.height, accuracy: 0.01)
    }

    // MARK: - MLMultiArray.setOnlyThisIndexToOne() Tests

    func testSetOnlyThisIndexToOneAtIndex0() throws {
        let array = try MLMultiArray(shape: [5], dataType: .double)

        // Set all values to some initial value
        for i in 0..<5 {
            array[i] = 0.5
        }

        array.setOnlyThisIndexToOne(0)

        XCTAssertEqual(array[0].doubleValue, 1.0)
        XCTAssertEqual(array[1].doubleValue, 0.0)
        XCTAssertEqual(array[2].doubleValue, 0.0)
        XCTAssertEqual(array[3].doubleValue, 0.0)
        XCTAssertEqual(array[4].doubleValue, 0.0)
    }

    func testSetOnlyThisIndexToOneAtMiddleIndex() throws {
        let array = try MLMultiArray(shape: [5], dataType: .double)

        array.setOnlyThisIndexToOne(2)

        XCTAssertEqual(array[0].doubleValue, 0.0)
        XCTAssertEqual(array[1].doubleValue, 0.0)
        XCTAssertEqual(array[2].doubleValue, 1.0)
        XCTAssertEqual(array[3].doubleValue, 0.0)
        XCTAssertEqual(array[4].doubleValue, 0.0)
    }

    func testSetOnlyThisIndexToOneAtLastIndex() throws {
        let array = try MLMultiArray(shape: [5], dataType: .double)

        array.setOnlyThisIndexToOne(4)

        XCTAssertEqual(array[0].doubleValue, 0.0)
        XCTAssertEqual(array[1].doubleValue, 0.0)
        XCTAssertEqual(array[2].doubleValue, 0.0)
        XCTAssertEqual(array[3].doubleValue, 0.0)
        XCTAssertEqual(array[4].doubleValue, 1.0)
    }

    func testSetOnlyThisIndexToOneWithInvalidIndex() throws {
        let array = try MLMultiArray(shape: [5], dataType: .double)

        // Set initial values
        for i in 0..<5 {
            array[i] = 0.5
        }

        // Invalid index - should not modify array (prints error)
        array.setOnlyThisIndexToOne(10)

        // Array should remain unchanged
        for i in 0..<5 {
            XCTAssertEqual(array[i].doubleValue, 0.5)
        }
    }

    // MARK: - createPlaneNode() Tests

    func testCreatePlaneNodeWithDefaultRotation() {
        let size = CGSize(width: 1.0, height: 2.0)
        let rotation: Float = 0.0

        let node = createPlaneNode(size: size, rotation: rotation, contents: UIColor.red)

        XCTAssertNotNil(node)
        XCTAssertNotNil(node.geometry)
        XCTAssertTrue(node.geometry is SCNPlane)

        let plane = node.geometry as! SCNPlane
        XCTAssertEqual(plane.width, size.width)
        XCTAssertEqual(plane.height, size.height)
        XCTAssertEqual(node.eulerAngles.x, rotation)
    }

    func testCreatePlaneNodeWithRotation() {
        let size = CGSize(width: 1.0, height: 1.0)
        let rotation: Float = Float.pi / 2  // 90 degrees

        let node = createPlaneNode(size: size, rotation: rotation, contents: nil)

        XCTAssertNotNil(node)
        XCTAssertEqual(node.eulerAngles.x, rotation, accuracy: 0.0001)
    }

    func testCreatePlaneNodeWithImageContents() {
        let size = CGSize(width: 1.0, height: 1.0)
        let rotation: Float = 0.0
        let testImage = UIImage(systemName: "square")

        let node = createPlaneNode(size: size, rotation: rotation, contents: testImage)

        XCTAssertNotNil(node)
        XCTAssertNotNil(node.geometry?.firstMaterial?.diffuse.contents)
    }
}
