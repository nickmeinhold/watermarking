/*
See LICENSE folder for this sample's licensing information.

Abstract:
A view controller that recognizes and tracks images found in the user's environment.
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

    var filter: CIFilter?
    var foreground: CIImage?
    var background: CIImage?
    var numCombined: Int = 0
    var accumulator: CIImageAccumulator?

    /// An object that detects rectangular shapes in the user's environment.
    let rectangleDetector = RectangleDetector()

    override func viewDidLoad() {
        super.viewDidLoad()

        filter = CIFilter(name: "WeightedCombine")
        accumulator = CIImageAccumulator(
            extent: CGRect(x: 0, y: 0, width: 512, height: 512),
            format: CIFormat.ARGB8
        )

        rectangleDetector.delegate = self
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

        // Reset accumulator state for fresh detection
        numCombined = 0
        background = nil
        foreground = nil
        imageView.image = nil

        let configuration = ARImageTrackingConfiguration()
        configuration.maximumNumberOfTrackedImages = 1
        configuration.trackingImages = []
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
	}

    /// Handles tap gesture input.
    @IBAction func didTap(_ sender: Any) {

    }
}

extension DetectionViewController: ARSCNViewDelegate {

    /// - Tag: ImageWasRecognized
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {

    }

    /// - Tag: DidUpdateAnchor
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {

    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arError = error as? ARError else { return }

        if arError.code == .invalidReferenceImage {
            // Restart the experience, as otherwise the AR session remains stopped.
            // There's no benefit in surfacing this error to the user.
            print("Error: The detected rectangle cannot be tracked.")
            return
        }

        let errorWithInfo = arError as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]

        // Use `compactMap(_:)` to remove optional error messages.
        let errorMessage = messages.compactMap { $0 }.joined(separator: "\n")

        DispatchQueue.main.async {
            // Present an alert informing about the error that just occurred.
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

        // Use UIGraphicsImageRenderer for modern image drawing
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

extension DetectionViewController: RectangleDetectorDelegate {
    /// Called when the app recognized a rectangular shape in the user's environment.
    /// - Tag: NewAlteredImage
    func rectangleFound(rectangleContent: CIImage) {
        // Skip accumulation - just show the latest frame directly
        DispatchQueue.main.async {
            self.imageView.image = UIImage.init(ciImage: rectangleContent)
        }
    }
}

// placeholder extension for editing later
// TODO(nickm): take the code from tapDetected() and turn into an extension
extension UIImage {

    /**
     Creates the JPEG data out of an UIImage
     @return Data
     */

    func generateJPEGRepresentation() -> Data? {
        let newImage = self.copyOriginalImage()
        return newImage?.jpegData(compressionQuality: 0.75)
    }

    /**
     Copies Original Image which fixes the crash for extracting Data from UIImage
     @return UIImage
     */

    private func copyOriginalImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: self.size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: self.size))
        }
    }
}
