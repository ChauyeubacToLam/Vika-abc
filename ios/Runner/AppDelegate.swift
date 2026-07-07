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

        guard let poseRegistrar = registrar(forPlugin: "PoseLandmarkerService") else {
            fatalError("Failed to get FlutterPluginRegistrar for PoseLandmarkerService")
        }
        let poseService = PoseLandmarkerService(
            textureRegistry: poseRegistrar.textures(),
            segmentationService: segmentationService
        )
        self.poseService = poseService

        let methodChannel = FlutterMethodChannel(
            name: "com.vikavn.app/pose_landmarker",
            binaryMessenger: controller.binaryMessenger
        )

        let eventChannel = FlutterEventChannel(
            name: "com.vikavn.app/pose_landmarker_stream",
            binaryMessenger: controller.binaryMessenger
        )

        let segmentationMethodChannel = FlutterMethodChannel(
            name: "com.vikavn.app/segmentation",
            binaryMessenger: controller.binaryMessenger
        )

        let segmentationEventChannel = FlutterEventChannel(
            name: "com.vikavn.app/segmentation_stream",
            binaryMessenger: controller.binaryMessenger
        )

        eventChannel.setStreamHandler(poseService)
        segmentationEventChannel.setStreamHandler(segmentationService)
        segmentationMethodChannel.setMethodCallHandler { [weak self] call, result in
            self?.segmentationService.handle(call, result: result)
        }

        methodChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {
            case "initialize":
                let args = call.arguments as? [String: Any]
                let useFrontCamera = (args?["useFrontCamera"] as? Bool) ?? true
                let initialOrientation = args?["initialOrientation"] as? String
                let isFrontCamera = args?["isFrontCamera"] as? Bool
                self.poseService?.initialize(
                    useFrontCamera: useFrontCamera,
                    initialOrientation: initialOrientation,
                    isFrontCamera: isFrontCamera
                ) { initializeResult in
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

            case "setDetectionInterval":
                let args = call.arguments as? [String: Any]
                let minDetectionIntervalMs = (args?["minDetectionIntervalMs"] as? Int) ?? 0
                self.poseService?.setDetectionInterval(minDetectionIntervalMs)
                result(nil)

            case "setOrientation":
                let args = call.arguments as? [String: Any]
                guard let orientation = args?["orientation"] as? String else {
                    result(FlutterError(
                        code: "pose_landmarker_orientation",
                        message: "Missing orientation.",
                        details: nil
                    ))
                    return
                }
                let isFrontCamera = (args?["isFrontCamera"] as? Bool) ?? false
                self.poseService?.setOrientation(orientation, isFrontCamera: isFrontCamera)
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
