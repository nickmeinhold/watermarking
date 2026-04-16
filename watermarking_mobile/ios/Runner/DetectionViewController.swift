/*
See LICENSE folder for this sample's licensing information.

Abstract:
A view controller that recognizes and tracks a known image in the user's
environment using ARKit image tracking, extracts the camera region via
perspective correction, and accumulates frames for noise reduction.
*/

import ARKit
import Foundation
import SceneKit
import UIKit

class DetectionViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var imageView: UIImageView!

    static var instance: DetectionViewController?

    var result: FlutterResult?
    var targetWidth: Int = 512
    var targetHeight: Int = 512

    /// URL of the original image to track (passed from Flutter).
    var referenceImageUrl: String?

    var filter: CIFilter?
    var numCombined: Int = 0
    var accumulator: CIImageAccumulator?
    /// Reusable context for force-rendering CIImages.
    /// Breaks lazy evaluation chains that reference recycled pixel buffers.
    let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    override func viewDidLoad() {
        super.viewDidLoad()

        filter = CIFilter(name: "WeightedCombine")
        accumulator = CIImageAccumulator(
            extent: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
            format: CIFormat.ARGB8
        )

        sceneView.delegate = self

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapDetected))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapRecognizer)
    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
        DetectionViewController.instance = self

		// Prevent the screen from being dimmed after a while.
		UIApplication.shared.isIdleTimerDisabled = true

        // Reset accumulator state for fresh detection.
        numCombined = 0
        imageView.image = nil

        guard let urlString = referenceImageUrl, let url = URL(string: urlString) else {
            result?(FlutterError(code: "NO_URL", message: "No reference image URL provided", details: nil))
            return
        }

        // Download the reference image and configure ARKit image tracking.
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self,
                  let data = data,
                  let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else {
                DispatchQueue.main.async {
                    self?.result?(FlutterError(
                        code: "DOWNLOAD_ERROR",
                        message: "Failed to download reference image",
                        details: error?.localizedDescription
                    ))
                }
                return
            }

            // Create ARReferenceImage with estimated physical size.
            // 0.2m (20cm) width is a reasonable default for a printed image.
            let physicalWidth: CGFloat = 0.2
            let referenceImage = ARReferenceImage(
                cgImage, orientation: .up, physicalWidth: physicalWidth
            )
            referenceImage.name = "watermarked-original"

            DispatchQueue.main.async {
                let configuration = ARImageTrackingConfiguration()
                configuration.maximumNumberOfTrackedImages = 1
                configuration.trackingImages = [referenceImage]
                self.sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
            }
        }.resume()
	}

    /// Handles tap gesture input.
    @IBAction func didTap(_ sender: Any) {

    }

    // MARK: - Image Extraction from ARImageAnchor

    /// Projects the tracked image's 3D corners to 2D camera coordinates,
    /// extracts the region via perspective correction, and accumulates frames.
    private func extractAndAccumulate(from imageAnchor: ARImageAnchor, frame: ARFrame) {
        let referenceSize = imageAnchor.referenceImage.physicalSize
        let halfW = Float(referenceSize.width / 2)
        let halfH = Float(referenceSize.height / 2)

        // Image corners in anchor-local 3D space.
        // ARKit: image lies in XZ plane, Y is the surface normal.
        let localCorners: [simd_float4] = [
            simd_float4(-halfW, 0, -halfH, 1),
            simd_float4(halfW, 0, -halfH, 1),
            simd_float4(-halfW, 0, halfH, 1),
            simd_float4(halfW, 0, halfH, 1)
        ]

        let anchorTransform = imageAnchor.transform
        let camera = frame.camera
        let imageResolution = camera.imageResolution
        let viewportSize = CGSize(width: imageResolution.width, height: imageResolution.height)

        // Project each 3D corner to 2D pixel coordinates.
        let pixelCorners = localCorners.map { localPoint -> CGPoint in
            let worldPoint = anchorTransform * localPoint
            return camera.projectPoint(
                simd_float3(worldPoint.x, worldPoint.y, worldPoint.z),
                orientation: .portrait,
                viewportSize: viewportSize
            )
        }

        // Create CIImage from camera pixel buffer.
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)
        let h = ciImage.extent.height

        // Apply perspective correction.
        // CIImage origin is bottom-left, so flip Y.
        guard let corrected = perspectiveCorrected(
            ciImage, corners: pixelCorners, height: h
        ) else { return }

        // Resize to target dimensions and translate to origin.
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        guard let resized = corrected.resize(to: targetSize) else { return }
        let translated = resized.transformed(by: CGAffineTransform(
            translationX: -resized.extent.origin.x,
            y: -resized.extent.origin.y
        ))

        accumulate(translated)
    }

    /// Applies CIPerspectiveCorrection with Y-flipped coordinates.
    private func perspectiveCorrected(
        _ image: CIImage, corners: [CGPoint], height h: CGFloat
    ) -> CIImage? {
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            return nil
        }
        let keys = ["inputTopLeft", "inputTopRight", "inputBottomLeft", "inputBottomRight"]
        for (i, key) in keys.enumerated() {
            let pt = CGPoint(x: corners[i].x, y: h - corners[i].y)
            filter.setValue(CIVector(cgPoint: pt), forKey: key)
        }
        filter.setValue(image, forKey: kCIInputImageKey)
        return filter.outputImage
    }

    /// Accumulates frames using WeightedCombine for noise reduction.
    ///
    /// Each frame is force-rendered via CIContext.createCGImage to break
    /// the lazy evaluation chain — ARKit recycles its pixel buffers every
    /// frame, so any CIImage still referencing one becomes invalid.
    private func accumulate(_ lazyFrame: CIImage) {
        let extent = CGRect(
            x: 0, y: 0,
            width: targetWidth, height: targetHeight
        )

        // Force-render to break lazy reference to ARKit's pixel buffer.
        guard let cgFrame = ciContext.createCGImage(
            lazyFrame, from: extent
        ) else { return }
        let frame = CIImage(cgImage: cgFrame)

        numCombined += 1

        if numCombined == 1 {
            accumulator?.setImage(frame)
        } else if let current = accumulator?.image() {
            // Force-render the current accumulated state too,
            // to avoid read-while-write on the accumulator buffer.
            guard let cgCurrent = ciContext.createCGImage(
                current, from: extent
            ) else { return }
            let renderedCurrent = CIImage(cgImage: cgCurrent)

            filter?.setValue(frame, forKey: kCIInputImageKey)
            filter?.setValue(
                renderedCurrent, forKey: "inputBackgroundImage"
            )
            filter?.setValue(
                NSNumber(value: numCombined - 1), forKey: "inputScale"
            )

            if let combined = filter?.outputImage,
               let cgCombined = ciContext.createCGImage(
                   combined, from: extent
               ) {
                accumulator?.setImage(CIImage(cgImage: cgCombined))
            }
        }

        guard let displayImage = accumulator?.image() else { return }
        DispatchQueue.main.async {
            self.imageView.image = UIImage(ciImage: displayImage)
        }
    }

    // MARK: - Tracking Boundary Visualization

    /// Adds an animated green border around the tracked image to show
    /// that ARKit has found and is tracking it.
    private func addTrackingBorder(
        to node: SCNNode, for imageAnchor: ARImageAnchor
    ) {
        let size = imageAnchor.referenceImage.physicalSize
        let w = Float(size.width)
        let h = Float(size.height)
        let halfW = w / 2
        let halfH = h / 2
        let thickness: CGFloat = 0.002  // 2mm border

        // Four edges of the tracked image boundary.
        let edges: [(CGSize, SCNVector3)] = [
            // top edge
            (CGSize(width: CGFloat(w), height: thickness),
             SCNVector3(0, 0.001, -halfH)),
            // bottom edge
            (CGSize(width: CGFloat(w), height: thickness),
             SCNVector3(0, 0.001, halfH)),
            // left edge
            (CGSize(width: thickness, height: CGFloat(h)),
             SCNVector3(-halfW, 0.001, 0)),
            // right edge
            (CGSize(width: thickness, height: CGFloat(h)),
             SCNVector3(halfW, 0.001, 0))
        ]

        for (i, (edgeSize, pos)) in edges.enumerated() {
            let plane = SCNPlane(
                width: edgeSize.width, height: edgeSize.height
            )
            plane.firstMaterial?.diffuse.contents = UIColor.green
            plane.firstMaterial?.isDoubleSided = true
            plane.firstMaterial?.emission.contents = UIColor.green

            let edgeNode = SCNNode(geometry: plane)
            edgeNode.eulerAngles.x = -.pi / 2
            edgeNode.position = pos
            edgeNode.opacity = 0

            // Animate: fade in with stagger, then pulse.
            let delay = Double(i) * 0.1
            let fadeIn = SCNAction.fadeOpacity(to: 0.8, duration: 0.3)
            let pulseOn = SCNAction.fadeOpacity(to: 1.0, duration: 0.15)
            let pulseOff = SCNAction.fadeOpacity(to: 0.5, duration: 0.15)
            let pulse = SCNAction.sequence([pulseOn, pulseOff])
            let settle = SCNAction.fadeOpacity(to: 0.6, duration: 0.2)

            let sequence = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                fadeIn,
                SCNAction.repeat(pulse, count: 2),
                settle
            ])

            edgeNode.runAction(sequence)
            node.addChildNode(edgeNode)
        }

        // Corner markers — small squares at each corner.
        let cornerSize: CGFloat = 0.008
        let corners: [SCNVector3] = [
            SCNVector3(-halfW, 0.001, -halfH),
            SCNVector3(halfW, 0.001, -halfH),
            SCNVector3(-halfW, 0.001, halfH),
            SCNVector3(halfW, 0.001, halfH)
        ]

        for (i, pos) in corners.enumerated() {
            let square = SCNPlane(
                width: cornerSize, height: cornerSize
            )
            square.cornerRadius = cornerSize / 2
            square.firstMaterial?.diffuse.contents = UIColor.green
            square.firstMaterial?.isDoubleSided = true
            square.firstMaterial?.emission.contents = UIColor.green

            let cornerNode = SCNNode(geometry: square)
            cornerNode.eulerAngles.x = -.pi / 2
            cornerNode.position = pos
            cornerNode.scale = SCNVector3(3, 3, 3)
            cornerNode.opacity = 0

            // Corners: appear large, shrink to position, flash.
            let delay = Double(i) * 0.08
            let appear = SCNAction.fadeOpacity(to: 0.9, duration: 0.2)
            let shrink = SCNAction.scale(to: 1.0, duration: 0.3)
            shrink.timingMode = .easeOut
            let group = SCNAction.group([appear, shrink])

            let flashOn = SCNAction.fadeOpacity(to: 1.0, duration: 0.1)
            let flashOff = SCNAction.fadeOpacity(to: 0.4, duration: 0.1)
            let flash = SCNAction.sequence([flashOn, flashOff])

            let sequence = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                group,
                SCNAction.repeat(flash, count: 2),
                SCNAction.fadeOpacity(to: 0.7, duration: 0.2)
            ])

            cornerNode.runAction(sequence)
            node.addChildNode(cornerNode)
        }
    }
}

extension DetectionViewController: ARSCNViewDelegate {

    /// Called when ARKit first detects the tracked image.
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor,
              let frame = sceneView.session.currentFrame else { return }
        extractAndAccumulate(from: imageAnchor, frame: frame)
        addTrackingBorder(to: node, for: imageAnchor)
    }

    /// Called each frame while the tracked image is visible.
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor,
              imageAnchor.isTracked,
              let frame = sceneView.session.currentFrame else { return }
        extractAndAccumulate(from: imageAnchor, frame: frame)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }

        if arError.code == .invalidReferenceImage {
            print("Error: The reference image could not be tracked.")
            return
        }

        let errorWithInfo = arError as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]

        let errorMessage = messages.compactMap { $0 }.joined(separator: "\n")

        DispatchQueue.main.async {
            let alertController = UIAlertController(
                title: "The AR session failed.",
                message: errorMessage,
                preferredStyle: .alert
            )
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    // Action
    @objc func tapDetected() {
        guard let originalImage = imageView.image else {
            result?(FlutterError(code: "SAVE_ERROR", message: "No image to save", details: nil))
            return
        }

        // Use UIGraphicsImageRenderer for modern image drawing.
        let renderer = UIGraphicsImageRenderer(size: originalImage.size)
        let newImage = renderer.image { _ in
            originalImage.draw(in: CGRect(origin: .zero, size: originalImage.size))
        }

        let fileName = "image.png"

        guard let data = newImage.pngData() else {
            result?(FlutterError(code: "SAVE_ERROR", message: "Failed to create PNG data", details: nil))
            return
        }

        do {
            let directory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let fileURL = directory.appendingPathComponent(fileName)
            try data.write(to: fileURL)
            result?(fileURL.path)
        } catch {
            result?(FlutterError(
                code: "SAVE_ERROR",
                message: "Failed to write image data",
                details: error.localizedDescription
            ))
        }
    }
}

extension UIImage {

    /// Creates the JPEG data out of an UIImage.
    func generateJPEGRepresentation() -> Data? {
        let newImage = self.copyOriginalImage()
        return newImage?.jpegData(compressionQuality: 0.75)
    }

    /// Copies original image, which fixes the crash for extracting Data from UIImage.
    private func copyOriginalImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: self.size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: self.size))
        }
    }
}
