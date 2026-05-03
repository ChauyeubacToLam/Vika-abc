import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let poseService = PoseLandmarkerService()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let methodChannel = FlutterMethodChannel(
            name: "com.vika.pose/methods",
            binaryMessenger: controller.binaryMessenger
        )

        let eventChannel = FlutterEventChannel(
            name: "com.vika.pose/stream",
            binaryMessenger: controller.binaryMessenger
        )

        eventChannel.setStreamHandler(poseService)

        methodChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {
            case "initialize":
                do {
                    try self.poseService.initialize()
                    result(true)
                } catch {
                    result(FlutterError(
                        code: "INIT_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }

            case "start":
                let args = call.arguments as? [String: Any]
                let camera = (args?["camera"] as? String) ?? "front"

                self.poseService.start(camera: camera) { startResult in
                    DispatchQueue.main.async {
                        switch startResult {
                        case .success:
                            result(true)
                        case .failure(let error):
                            result(FlutterError(
                                code: "START_FAILED",
                                message: error.localizedDescription,
                                details: nil
                            ))
                        }
                    }
                }

            case "stop":
                self.poseService.stop()
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}