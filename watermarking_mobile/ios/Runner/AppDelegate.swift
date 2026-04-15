import UIKit
import Flutter

enum ChannelName {
    static let detect = "watermarking.enspyr.co/detect"
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GeneratedPluginRegistrant.register(with: self)

    CIFilter.registerName(
        "WeightedCombine",
        constructor: CustomFiltersVendor(),
        classAttributes: [kCIAttributeFilterCategories: [kCICategoryVideo, kCICategoryStillImage]]
    )

    guard let controller = window?.rootViewController as? FlutterViewController else {
        fatalError("rootViewController is not type FlutterViewController")
    }
    let detectChannel = FlutterMethodChannel(
        name: ChannelName.detect,
        binaryMessenger: controller.binaryMessenger
    )
    detectChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "dismiss" {
            self?.window?.rootViewController?.dismiss(animated: false, completion: nil)
            return
        }

        guard call.method == "startDetection" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let arguments = call.arguments as? NSDictionary,
              let width = arguments["width"] as? Int,
              let height = arguments["height"] as? Int,
              let imageUrl = arguments["imageUrl"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing width, height, or imageUrl arguments", details: nil))
            return
        }

        print("\nwidth: \(width), height: \(height), imageUrl: \(imageUrl)\n")

        // navigate to DetectionViewController
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let viewController = storyboard.instantiateViewController(
            withIdentifier: "DetectionVC"
        ) as? DetectionViewController else {
            result(FlutterError(
                code: "VC_ERROR",
                message: "Could not instantiate DetectionViewController",
                details: nil
            ))
            return
        }
        viewController.result = result
        viewController.targetWidth = width
        viewController.targetHeight = height
        viewController.referenceImageUrl = imageUrl
        controller.present(viewController, animated: true, completion: nil)

    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
