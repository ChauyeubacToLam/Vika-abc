import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var poseService: PoseLandmarkerService?
    private let segmentationService = SegmentationService()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let poseRegistrar = registrar(forPlugin: "PoseLandmarkerService")
        let poseService = PoseLandmarkerService(textureRegistry: poseRegistrar.textures())
        self.poseService = poseService

        let methodChannel = FlutterMethodChannel(
            name: "com.vikavn.app/pose_landmarker",
            binaryMessenger: controller.binaryMessenger
        )

        let eventChannel = FlutterEventChannel(
            name: "com.vikavn.app/pose_landmarker_stream",
            binaryMessenger: controller.binaryMessenger
        )

        let segmentationEventChannel = FlutterEventChannel(
            name: "com.vikavn.app/segmentation",
            binaryMessenger: controller.binaryMessenger
        )

        eventChannel.setStreamHandler(poseService)
        segmentationEventChannel.setStreamHandler(segmentationService)

        methodChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {
            case "initialize":
                let args = call.arguments as? [String: Any]
                let useFrontCamera = (args?["useFrontCamera"] as? Bool) ?? false
                self.poseService?.initialize(useFrontCamera: useFrontCamera) { initializeResult in
                    DispatchQueue.main.async {
                        switch initializeResult {
                        case .success(let textureId):
                            result(textureId)
                        case .failure(let error):
                            result(FlutterError(
                                code: "pose_landmarker_init",
                                message: error.localizedDescription,
                                details: nil
                            ))
                        }
                    }
                }

            case "dispose":
                self.poseService?.dispose()
                result(nil)

            case "switchCamera":
                self.poseService?.switchCamera { switchResult in
                    DispatchQueue.main.async {
                        switch switchResult {
                        case .success:
                            result(nil)
                        case .failure(let error):
                            result(FlutterError(
                                code: "pose_landmarker_switch_camera",
                                message: error.localizedDescription,
                                details: nil
                            ))
                        }
                    }
                }

            case "startDetection":
                self.poseService?.startDetection()
                result(nil)

            case "stopDetection":
                self.poseService?.stopDetection()
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
