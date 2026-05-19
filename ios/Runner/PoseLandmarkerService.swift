import Foundation
import AVFoundation
import Flutter
import UIKit
import MediaPipeTasksVision

final class PoseLandmarkerService: NSObject,
                                   FlutterStreamHandler,
                                   FlutterTexture,
                                   AVCaptureVideoDataOutputSampleBufferDelegate,
                                   PoseLandmarkerLiveStreamDelegate {

    private let textureRegistry: FlutterTextureRegistry
    private weak var segmentationService: SegmentationService?
    private var eventSink: FlutterEventSink?
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.vikavn.app.pose.session")
    private let pixelBufferQueue = DispatchQueue(label: "com.vikavn.app.pose.texture")
    private let pendingFrameQueue = DispatchQueue(label: "com.vikavn.app.pose.pending_frames")
    private var latestPixelBuffer: Unmanaged<CVPixelBuffer>?
    private var textureId: Int64?
    private var videoOutput = AVCaptureVideoDataOutput()
    private var poseLandmarker: PoseLandmarker?
    private var currentCameraPosition: AVCaptureDevice.Position = .front
    private var currentOrientation: UIImage.Orientation = .up
    private var currentSegmentationOrientation: UIImage.Orientation = .up
    private var currentOrientationCode: String?
    private var detectionEnabled = true
    private var lastSubmittedTimestampMs = Int.min
    private var pendingFrames: [Int: FramePayload] = [:]

    init(textureRegistry: FlutterTextureRegistry,
         segmentationService: SegmentationService? = nil) {
        self.textureRegistry = textureRegistry
        self.segmentationService = segmentationService
        super.init()
    }

    // MARK: - Flutter stream handler
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - Flutter texture
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        var pixelBuffer: Unmanaged<CVPixelBuffer>?
        pixelBufferQueue.sync {
            pixelBuffer = latestPixelBuffer
            latestPixelBuffer = nil
        }

        return pixelBuffer
    }

    // MARK: - Public API matching lib/pose/pose_landmarker_channel.dart
    func initialize(useFrontCamera: Bool,
                    initialOrientation: String?,
                    isFrontCamera: Bool?,
                    completion: @escaping (Result<Int64, Error>) -> Void) {
        sessionQueue.async {
            do {
                try self.initializeLandmarker()
                self.currentCameraPosition = useFrontCamera ? .front : .back
                self.applyOrientation(
                    initialOrientation,
                    isFrontCamera: isFrontCamera ?? useFrontCamera
                )
                self.detectionEnabled = true
                let textureId = self.ensureTexture()
                try self.configureCaptureSession()
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
                completion(.success(textureId))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func setOrientation(_ orientation: String, isFrontCamera: Bool) {
        sessionQueue.async {
            self.applyOrientation(orientation, isFrontCamera: isFrontCamera)
        }
    }

    func startDetection() {
        sessionQueue.async {
            self.detectionEnabled = true
        }
    }

    func stopDetection() {
        sessionQueue.async {
            self.detectionEnabled = false
        }
    }

    func switchCamera(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            let previousPosition = self.currentCameraPosition
            self.currentCameraPosition = previousPosition == .front ? .back : .front
            if let currentOrientationCode = self.currentOrientationCode {
                self.applyOrientation(
                    currentOrientationCode,
                    isFrontCamera: self.currentCameraPosition == .front
                )
            }

            do {
                try self.configureCaptureSession()
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
                completion(.success(()))
            } catch {
                self.currentCameraPosition = previousPosition
                completion(.failure(error))
            }
        }
    }

    func dispose() {
        sessionQueue.async {
            self.detectionEnabled = false
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
            self.captureSession.beginConfiguration()
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }
            for output in self.captureSession.outputs {
                self.captureSession.removeOutput(output)
            }
            self.captureSession.commitConfiguration()
            self.poseLandmarker = nil
            self.pendingFrameQueue.sync {
                self.pendingFrames.removeAll()
            }
            self.lastSubmittedTimestampMs = Int.min
            self.pixelBufferQueue.sync {
                if let latestPixelBuffer = self.latestPixelBuffer {
                    latestPixelBuffer.release()
                }
                self.latestPixelBuffer = nil
            }

            DispatchQueue.main.async {
                if let textureId = self.textureId {
                    self.textureRegistry.unregisterTexture(textureId)
                    self.textureId = nil
                }
                self.eventSink = nil
            }
        }
    }

    // MARK: - Pose landmarker
    private func applyOrientation(_ orientation: String?, isFrontCamera: Bool) {
        guard let orientation = orientation else {
            currentOrientationCode = nil
            currentOrientation = .up
            currentSegmentationOrientation = .up
            segmentationService?.setOrientation(.up)
            return
        }

        currentOrientationCode = orientation

        // Rotate the AVCapture connection to match the device orientation.
        // With this the pixel buffer comes out already oriented for the
        // current device rotation (portrait stays portrait, landscape comes
        // out landscape), so MediaPipe only has to handle the front-camera
        // mirror — no 90° rotation gymnastics needed.
        if let connection = videoOutput.connection(with: .video) {
            let videoOrientation = Self.captureVideoOrientation(from: orientation)
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isFrontCamera
            }
        }

        let resolvedOrientation: UIImage.Orientation =
            isFrontCamera ? .upMirrored : .up
        currentOrientation = resolvedOrientation.withoutMirroring
        currentSegmentationOrientation = resolvedOrientation
        segmentationService?.setOrientation(resolvedOrientation)
    }

    static func imageOrientation(from orientation: String, isFrontCamera: Bool) -> UIImage.Orientation {
        // Kept for SegmentationService compatibility. Always returns the
        // mirror-only orientation since the capture connection now rotates
        // the buffer to match the device.
        return isFrontCamera ? .upMirrored : .up
    }

    private static func captureVideoOrientation(
        from orientation: String
    ) -> AVCaptureVideoOrientation {
        // Convention swap on landscape only.
        //
        // The string we receive comes from `native_device_orientation`, which
        // follows `UIDeviceOrientation` semantics (per the package's iOS
        // DisplayOrientationListener: "landscapeLeft = home button on RIGHT").
        //
        // `AVCaptureVideoOrientation` shares enum values with
        // `UIInterfaceOrientation`, and per Apple's UIOrientation.h header,
        //   UIInterfaceOrientationLandscapeLeft  = UIDeviceOrientationLandscapeRight,
        //   UIInterfaceOrientationLandscapeRight = UIDeviceOrientationLandscapeLeft
        // — i.e. the landscape names are inverted between the two enums.
        //
        // To rotate the buffer to the user's *actual* physical view, we map:
        //   sensor "landscapeLeft" (UIDevice.landscapeLeft, home button RIGHT)
        //     → AVCapture.landscapeRight (= UIInterface.landscapeRight, home button RIGHT)
        //   sensor "landscapeRight" (UIDevice.landscapeRight, home button LEFT)
        //     → AVCapture.landscapeLeft (= UIInterface.landscapeLeft, home button LEFT)
        //
        // Portrait and portraitUpsideDown share enum values across both
        // conventions, so they don't need to be swapped.
        switch orientation {
        case "portrait":
            return .portrait
        case "portraitUpsideDown":
            return .portraitUpsideDown
        case "landscapeLeft":
            return .landscapeRight
        case "landscapeRight":
            return .landscapeLeft
        default:
            return .portrait
        }
    }

    private func initializeLandmarker() throws {
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
            print("[PoseLandmarker] GPU init failed: \(error.localizedDescription). Falling back to CPU.")
            options.baseOptions.delegate = .CPU
            poseLandmarker = try PoseLandmarker(options: options)
        }
    }

    private func ensureTexture() -> Int64 {
        if let textureId = textureId {
            return textureId
        }

        var registeredTextureId: Int64 = 0
        DispatchQueue.main.sync {
            registeredTextureId = textureRegistry.register(self)
            textureId = registeredTextureId
        }
        return registeredTextureId
    }

    // MARK: - Camera
    private func configureCaptureSession() throws {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }
        if captureSession.canSetSessionPreset(.hd1280x720) {
            captureSession.sessionPreset = .hd1280x720
        } else if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        } else {
            captureSession.sessionPreset = .vga640x480
        }

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
        configureCameraDevice(camera)

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
            // Default to portrait; applyOrientation() updates this whenever
            // Flutter sends a new device orientation.
            let initialVideoOrientation: AVCaptureVideoOrientation = {
                guard let code = currentOrientationCode else { return .portrait }
                return Self.captureVideoOrientation(from: code)
            }()
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = initialVideoOrientation
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = currentCameraPosition == .front
            }
        }

    }

    private func configureCameraDevice(_ camera: AVCaptureDevice) {
        let targetFps: Double = 30
        let supportsTargetFps = camera.activeFormat.videoSupportedFrameRateRanges.contains { range in
            range.minFrameRate <= targetFps && targetFps <= range.maxFrameRate
        }

        do {
            try camera.lockForConfiguration()
            defer {
                camera.unlockForConfiguration()
            }
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isSmoothAutoFocusSupported {
                camera.isSmoothAutoFocusEnabled = true
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                camera.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            camera.videoZoomFactor = camera.minAvailableVideoZoomFactor
            if supportsTargetFps {
                let frameDuration = CMTime(value: 1, timescale: 30)
                camera.activeVideoMinFrameDuration = frameDuration
                camera.activeVideoMaxFrameDuration = frameDuration
            }
        } catch {
            print("[PoseLandmarker] Could not configure camera device: \(error.localizedDescription)")
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let retainedPixelBuffer = Unmanaged.passRetained(pixelBuffer)
        pixelBufferQueue.sync {
            if let latestPixelBuffer = latestPixelBuffer {
                latestPixelBuffer.release()
            }
            latestPixelBuffer = retainedPixelBuffer
        }
        if let textureId = textureId {
            DispatchQueue.main.async {
                self.textureRegistry.textureFrameAvailable(textureId)
            }
        }

        guard detectionEnabled, let poseLandmarker = poseLandmarker else {
            return
        }

        let timestampMs = Int(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds * 1000.0)
        if timestampMs <= lastSubmittedTimestampMs {
            return
        }

        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        let imageDimensions = Self.orientedImageDimensions(
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            orientationCode: currentOrientationCode
        )
        segmentationService?.detect(
            sampleBuffer: sampleBuffer,
            timestampMs: timestampMs,
            imageWidth: imageDimensions.width,
            imageHeight: imageDimensions.height,
            orientation: currentSegmentationOrientation
        )

        storePendingFrame(
            timestampMs: timestampMs,
            payload: FramePayload(
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                imageWidth: imageDimensions.width,
                imageHeight: imageDimensions.height,
                rotationDegrees: 0,
                isFrontCamera: currentCameraPosition == .front
            )
        )

        do {
            let mpImage = try MPImage(sampleBuffer: sampleBuffer, orientation: currentOrientation)
            lastSubmittedTimestampMs = timestampMs
            try poseLandmarker.detectAsync(image: mpImage, timestampInMilliseconds: timestampMs)
        } catch {
            _ = removePendingFrame(timestampMs: timestampMs)
            sendError(code: "pose_landmarker_detection", message: error.localizedDescription)
        }
    }

    // MARK: - PoseLandmarkerLiveStreamDelegate
    func poseLandmarker(_ poseLandmarker: PoseLandmarker,
                        didFinishDetection result: PoseLandmarkerResult?,
                        timestampInMilliseconds: Int,
                        error: Error?) {
        if let error = error {
            sendError(code: "pose_landmarker_stream", message: error.localizedDescription)
            return
        }

        guard let framePayload = removePendingFrame(timestampMs: timestampInMilliseconds) else {
            return
        }

        let firstPose = result?.landmarks.first
        let firstWorldPose = result?.worldLandmarks.first
        let landmarks = firstPose?.enumerated().map { index, landmark in
            landmarkToMap(index: index, landmark: landmark)
        } ?? []
        let worldLandmarks = firstWorldPose?.enumerated().map { index, landmark in
            worldLandmarkToMap(index: index, landmark: landmark)
        } ?? []

        DispatchQueue.main.async {
            self.eventSink?(
                framePayload.toEventPayload(
                    timestampMs: timestampInMilliseconds,
                    landmarks: landmarks,
                    worldLandmarks: worldLandmarks
                )
            )
        }
    }

    private func landmarkToMap(index: Int, landmark: NormalizedLandmark) -> [String: Any] {
        [
            "type": index,
            "x": landmark.x,
            "y": landmark.y,
            "z": landmark.z,
            "presence": landmarkPresence(
                visibility: landmark.visibility,
                presence: landmark.presence
            ),
            "visibility": landmarkVisibility(
                visibility: landmark.visibility,
                presence: landmark.presence
            ),
            "likelihood": landmarkScore(visibility: landmark.visibility, presence: landmark.presence),
        ]
    }

    private func worldLandmarkToMap(index: Int, landmark: Landmark) -> [String: Any] {
        [
            "type": index,
            "x": landmark.x,
            "y": landmark.y,
            "z": landmark.z,
            "presence": landmarkPresence(
                visibility: landmark.visibility,
                presence: landmark.presence
            ),
            "visibility": landmarkVisibility(
                visibility: landmark.visibility,
                presence: landmark.presence
            ),
            "likelihood": landmarkScore(visibility: landmark.visibility, presence: landmark.presence),
        ]
    }

    private func landmarkScore(visibility: NSNumber?, presence: NSNumber?) -> Float {
        (visibility ?? presence)?.floatValue ?? 0.0
    }

    private func landmarkPresence(visibility: NSNumber?, presence: NSNumber?) -> Float {
        (presence ?? visibility)?.floatValue ?? 0.0
    }

    private func landmarkVisibility(visibility: NSNumber?, presence: NSNumber?) -> Float {
        (visibility ?? presence)?.floatValue ?? 0.0
    }

    private func storePendingFrame(timestampMs: Int, payload: FramePayload) {
        pendingFrameQueue.sync {
            pendingFrames[timestampMs] = payload
            trimPendingFrames()
        }
    }

    private func removePendingFrame(timestampMs: Int) -> FramePayload? {
        pendingFrameQueue.sync {
            pendingFrames.removeValue(forKey: timestampMs)
        }
    }

    private func trimPendingFrames(maxEntries: Int = 4) {
        guard pendingFrames.count > maxEntries else { return }
        let keysToDrop = pendingFrames.keys.sorted().prefix(pendingFrames.count - maxEntries)
        for key in keysToDrop {
            pendingFrames.removeValue(forKey: key)
        }
    }

    private func sendError(code: String, message: String) {
        DispatchQueue.main.async {
            self.eventSink?(FlutterError(code: code, message: message, details: nil))
        }
    }

    private static func orientedImageDimensions(frameWidth: Int,
                                                frameHeight: Int,
                                                orientationCode: String?) -> (width: Int, height: Int) {
        // The capture connection now rotates the buffer to match the device,
        // so frameWidth/frameHeight already reflect the visible orientation.
        // Landmarks are normalized to the same buffer, so just pass through.
        return (width: frameWidth, height: frameHeight)
    }

    private struct FramePayload {
        let frameWidth: Int
        let frameHeight: Int
        let imageWidth: Int
        let imageHeight: Int
        let rotationDegrees: Int
        let isFrontCamera: Bool

        func toEventPayload(timestampMs: Int,
                            landmarks: [[String: Any]],
                            worldLandmarks: [[String: Any]]) -> [String: Any] {
            [
                "landmarks": landmarks,
                "worldLandmarks": worldLandmarks,
                "imageWidth": imageWidth,
                "imageHeight": imageHeight,
                "frameWidth": frameWidth,
                "frameHeight": frameHeight,
                "rotationDegrees": rotationDegrees,
                "isFrontCamera": isFrontCamera,
                "timestampMs": timestampMs,
            ]
        }
    }
}

private extension UIImage.Orientation {
    var withoutMirroring: UIImage.Orientation {
        switch self {
        case .upMirrored:
            return .up
        case .downMirrored:
            return .down
        case .leftMirrored:
            return .left
        case .rightMirrored:
            return .right
        default:
            return self
        }
    }
}
