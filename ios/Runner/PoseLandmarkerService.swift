import Foundation
import AVFoundation
import Flutter
import UIKit
import MediaPipeTasksVision

final class PoseLandmarkerService: NSObject,
                                   FlutterStreamHandler,
                                   AVCaptureVideoDataOutputSampleBufferDelegate,
                                   PoseLandmarkerLiveStreamDelegate {

    private static var didFinishDiagnosticLogging = false
    private static var diagnosticFrameIndex = 0

    private var eventSink: FlutterEventSink?
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.vika.pose.session")
    private var videoOutput = AVCaptureVideoDataOutput()
    private var poseLandmarker: PoseLandmarker?
    private var currentCameraPosition: AVCaptureDevice.Position = .front

    // MARK: - Flutter stream handler
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - Public API
    func initialize() throws {
        if poseLandmarker != nil { return }

        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_lite", ofType: "task") else {
            throw NSError(
                domain: "PoseLandmarkerService",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Khong tim thay pose_landmarker_lite.task trong Runner bundle"]
            )
        }

       let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.baseOptions.delegate = .GPU
        options.runningMode = .liveStream
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.5
        options.minPosePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.7
        options.poseLandmarkerLiveStreamDelegate = self

        do {
            poseLandmarker = try PoseLandmarker(options: options)
        } catch {
            // GPU init failed (e.g., simulator, older device, Metal shader compile issue).
            // Fall back to CPU. If CPU also fails, throw to native init handler.
            print("[PoseLandmarker] GPU init failed: \(error.localizedDescription). Falling back to CPU.")
            options.baseOptions.delegate = .CPU
            poseLandmarker = try PoseLandmarker(options: options)
        }
    }

    func start(camera: String = "front", completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            do {
                try self.initialize()
                self.currentCameraPosition = camera.lowercased() == "back" ? .back : .front
                try self.configureCaptureSession()
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    // MARK: - Camera
    private func configureCaptureSession() throws {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480

        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: currentCameraPosition) else {
            throw NSError(
                domain: "PoseLandmarkerService",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Khong tim thay camera"]
            )
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(input) else {
            throw NSError(
                domain: "PoseLandmarkerService",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Khong add duoc camera input"]
            )
        }
        captureSession.addInput(input)

        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            throw NSError(
                domain: "PoseLandmarkerService",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Khong add duoc video output"]
            )
        }
        captureSession.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (currentCameraPosition == .front)
            }
        }

        captureSession.commitConfiguration()
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let poseLandmarker = poseLandmarker else { return }

        let timestampMs = Int(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds * 1000.0)

        do {
            // Portrait-first.
            // Neu thay trai/phai dao, doi .leftMirrored -> .right cho camera truoc.
            let orientation: UIImage.Orientation = currentCameraPosition == .front ? .leftMirrored : .right
            let mpImage = try MPImage(sampleBuffer: sampleBuffer, orientation: orientation)
            try poseLandmarker.detectAsync(image: mpImage, timestampInMilliseconds: timestampMs)
        } catch {
            sendError(code: "POSE_STREAM_ERROR", message: error.localizedDescription)
        }
    }

    // MARK: - PoseLandmarkerLiveStreamDelegate
    func poseLandmarker(_ poseLandmarker: PoseLandmarker,
                        didFinishDetection result: PoseLandmarkerResult?,
                        timestampInMilliseconds: Int,
                        error: Error?) {
        Self.logDiagnosticFrame(result: result)

        if let error = error {
            sendError(code: "POSE_DETECTION_FAILED", message: error.localizedDescription)
            return
        }

        guard let firstPose = result?.landmarks.first else {
            DispatchQueue.main.async {
                self.eventSink?([
                    "timestamp": timestampInMilliseconds,
                    "poseDetected": false,
                    "landmarks": []
                ])
            }
            return
        }

        let landmarks: [[String: Any]] = firstPose.enumerated().map { index, landmark in
            [
                "index": index,
                "x": landmark.x,
                "y": landmark.y,
                "z": landmark.z
            ]
        }

        DispatchQueue.main.async {
            self.eventSink?([
                "timestamp": timestampInMilliseconds,
                "poseDetected": true,
                "landmarks": landmarks
            ])
        }
    }

    private func sendError(code: String, message: String) {
        DispatchQueue.main.async {
            self.eventSink?(FlutterError(code: code, message: message, details: nil))
        }
    }

    private static func logDiagnosticFrame(result: PoseLandmarkerResult?) {
        guard !didFinishDiagnosticLogging else { return }

        let frameIndex = diagnosticFrameIndex
        let poses = result?.landmarks ?? []

        if poses.isEmpty {
            print("[VIKA-DIAG] frame=\(frameIndex) landmarks=empty")
        } else {
            let landmark = poses[0][0]
            print(
                "[VIKA-DIAG] frame=\(frameIndex) landmarks=poses count=\(poses.count) landmark[0][0]=\(String(describing: landmark)) x=\(String(describing: landmark.x)) y=\(String(describing: landmark.y)) z=\(String(describing: landmark.z)) visibility=\(String(describing: landmark.visibility)) presence=\(String(describing: landmark.presence))"
            )
        }

        diagnosticFrameIndex += 1
        if diagnosticFrameIndex >= 30 {
            didFinishDiagnosticLogging = true
        }
    }
}
