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
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
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
            let aspectRatio = CGFloat(cgImage.height) / CGFloat(cgImage.width)
            let physicalWidth: CGFloat = 0.2
            let physicalSize = CGSize(width: physicalWidth, height: physicalWidth * aspectRatio)
            let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalSize: physicalSize)
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
            simd_float4(-halfW, 0, -halfH, 1),  // top-left
            simd_float4( halfW, 0, -halfH, 1),  // top-right
            simd_float4(-halfW, 0,  halfH, 1),  // bottom-left
            simd_float4( halfW, 0,  halfH, 1),  // bottom-right
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
        guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else { return }
        perspectiveFilter.setValue(CIVector(cgPoint: CGPoint(x: pixelCorners[0].x, y: h - pixelCorners[0].y)), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: CGPoint(x: pixelCorners[1].x, y: h - pixelCorners[1].y)), forKey: "inputTopRight")
        perspectiveFilter.setValue(CIVector(cgPoint: CGPoint(x: pixelCorners[2].x, y: h - pixelCorners[2].y)), forKey: "inputBottomLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: CGPoint(x: pixelCorners[3].x, y: h - pixelCorners[3].y)), forKey: "inputBottomRight")
        perspectiveFilter.setValue(ciImage, forKey: kCIInputImageKey)

        guard let corrected = perspectiveFilter.outputImage else { return }

        // Resize to target dimensions.
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        guard let resized = corrected.resize(to: targetSize) else { return }

        // Translate to origin (resize preserves original extent origin).
        let translated = resized.transformed(by: CGAffineTransform(
            translationX: -resized.extent.origin.x,
            y: -resized.extent.origin.y
        ))

        // Accumulate for noise reduction using WeightedCombine Metal filter.
        numCombined += 1

        if numCombined == 1 {
            accumulator?.setImage(translated)
        } else if let currentAccumulated = accumulator?.image() {
            filter?.setValue(translated, forKey: kCIInputImageKey)
            filter?.setValue(currentAccumulated, forKey: "inputBackgroundImage")
            filter?.setValue(NSNumber(value: numCombined - 1), forKey: "inputScale")

            if let combined = filter?.outputImage {
                accumulator?.setImage(combined)
            }
        }

        guard let displayImage = accumulator?.image() else { return }
        DispatchQueue.main.async {
            self.imageView.image = UIImage(ciImage: displayImage)
        }
    }

    // MARK: - Feature Circle Visualization

    /// Adds animated green circles on the tracked image surface to show
    /// feature tracking. Circles start large, shrink to enclose the feature
    /// point, then flash.
    private func addFeatureCircles(to node: SCNNode, for imageAnchor: ARImageAnchor) {
        let size = imageAnchor.referenceImage.physicalSize
        let halfW = Float(size.width / 2)
        let halfH = Float(size.height / 2)

        // Create a grid of feature points across the image surface.
        let cols = 5
        let rows = 5
        let finalRadius: CGFloat = 0.003  // 3mm circle at rest
        let startScale: Float = 5.0       // Start 5x larger

        for row in 0..<rows {
            for col in 0..<cols {
                // Position in anchor-local space (XZ plane, Y is normal).
                let x = -halfW + Float(col) * (2 * halfW) / Float(cols - 1)
                let z = -halfH + Float(row) * (2 * halfH) / Float(rows - 1)

                // Green circle as a small flat disc.
                let circle = SCNPlane(width: finalRadius * 2, height: finalRadius * 2)
                circle.cornerRadius = finalRadius
                circle.firstMaterial?.diffuse.contents = UIColor.green
                circle.firstMaterial?.isDoubleSided = true
                circle.firstMaterial?.emission.contents = UIColor.green

                let circleNode = SCNNode(geometry: circle)
                // Lay flat on the image surface (rotate from XY to XZ plane).
                circleNode.eulerAngles.x = -.pi / 2
                circleNode.position = SCNVector3(x, 0.001, z)  // Slightly above surface
                circleNode.scale = SCNVector3(startScale, startScale, startScale)
                circleNode.opacity = 0.8

                // Stagger animation start per circle.
                let delay = Double(row * cols + col) * 0.03

                // Animation: shrink → flash → settle.
                let shrink = SCNAction.scale(to: 1.0, duration: 0.4)
                shrink.timingMode = .easeOut

                let flashOn = SCNAction.fadeOpacity(to: 1.0, duration: 0.1)
                let flashOff = SCNAction.fadeOpacity(to: 0.4, duration: 0.1)
                let flash = SCNAction.sequence([flashOn, flashOff, flashOn, flashOff])

                let settle = SCNAction.fadeOpacity(to: 0.6, duration: 0.3)

                let sequence = SCNAction.sequence([
                    SCNAction.wait(duration: delay),
                    shrink,
                    flash,
                    settle,
                ])

                circleNode.runAction(sequence)
                node.addChildNode(circleNode)
            }
        }
    }
}

extension DetectionViewController: ARSCNViewDelegate {

    /// Called when ARKit first detects the tracked image.
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor,
              let frame = sceneView.session.currentFrame else { return }
        extractAndAccumulate(from: imageAnchor, frame: frame)
        addFeatureCircles(to: node, for: imageAnchor)
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
