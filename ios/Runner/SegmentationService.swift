import Foundation
import AVFoundation
import Flutter
import UIKit
import MLKitSegmentationCommon
import MLKitSegmentationSelfie
import MLKitVision

private final class RetainedSampleBuffer: @unchecked Sendable {
    private let retainedBuffer: Unmanaged<CMSampleBuffer>

    init(_ sampleBuffer: CMSampleBuffer) {
        retainedBuffer = Unmanaged.passRetained(sampleBuffer)
    }

    var value: CMSampleBuffer {
        retainedBuffer.takeUnretainedValue()
    }

    deinit {
        retainedBuffer.release()
    }
}

/*
 * Native selfie segmentation channel contract.
 *
 * MethodChannel("com.vikavn.app/segmentation"):
 * - initialize({ pixelConfidenceThreshold?, softPixelConfidenceThreshold?,
 *                minProcessIntervalMs? }) -> { success: true }
 * - start() -> { success: true }
 * - stop() -> { success: true }
 * - dispose() -> { success: true }
 *
 * EventChannel("com.vikavn.app/segmentation_stream") emits:
 * {
 *   timestampMs: Int,
 *   imageWidth: Int,
 *   imageHeight: Int,
 *   personRatio: Double,
 *   softPersonRatio: Double
 * }
 *
 * The pose camera pipeline owns frames and calls detect(). Raw masks and camera
 * bytes never cross the Flutter platform channel.
 */
final class SegmentationService: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var segmenter: Segmenter?
    private let stateQueue = DispatchQueue(label: "com.vikavn.app.segmentation.state")
    private var isRunning = false
    private var isProcessing = false
    private var lastProcessedTimestampMs = Int.min
    private var pixelConfidenceThreshold: Float = 0.92
    private var softPixelConfidenceThreshold: Float = 0.55
    private var minProcessIntervalMs = 140

    override init() {
        super.init()
        setupSegmenter()
    }

    // MARK: - Flutter method surface
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            let args = call.arguments as? [String: Any]
            if let threshold = args?["pixelConfidenceThreshold"] as? NSNumber {
                pixelConfidenceThreshold = threshold.floatValue
            }
            if let threshold = args?["softPixelConfidenceThreshold"] as? NSNumber {
                softPixelConfidenceThreshold = threshold.floatValue
            }
            if let interval = args?["minProcessIntervalMs"] as? NSNumber {
                minProcessIntervalMs = interval.intValue
            }
            setupSegmenter()
            result(["success": true])

        case "start":
            stateQueue.async {
                self.isRunning = true
            }
            result(["success": true])

        case "stop":
            stateQueue.async {
                self.isRunning = false
            }
            result(["success": true])

        case "dispose":
            disposeSegmenter()
            result(["success": true])

        case "debugLog":
            if let args = call.arguments as? [String: Any],
               let message = args["message"] as? String {
                print("[VIKA-DIAG] \(message)")
            }
            result(["success": true])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Flutter stream handler
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // MARK: - Public API
    func detect(sampleBuffer: CMSampleBuffer,
                timestampMs: Int,
                imageWidth: Int,
                imageHeight: Int,
                orientation: UIImage.Orientation = .up) {
        var shouldProcess = false
        stateQueue.sync {
            if isRunning &&
                !isProcessing &&
                (lastProcessedTimestampMs == Int.min ||
                    timestampMs - lastProcessedTimestampMs >= minProcessIntervalMs) {
                isProcessing = true
                lastProcessedTimestampMs = timestampMs
                shouldProcess = true
            }
        }

        guard shouldProcess, let activeSegmenter = segmenter else {
            return
        }

        let copiedSampleBuffer: CMSampleBuffer
        do {
            copiedSampleBuffer = try copySampleBuffer(sampleBuffer)
        } catch {
            stateQueue.async {
                self.isProcessing = false
            }
            sendError(code: "SEGMENTATION_COPY_FAILED", message: error.localizedDescription)
            return
        }

        let retainedSampleBuffer = RetainedSampleBuffer(copiedSampleBuffer)
        let image = VisionImage(buffer: retainedSampleBuffer.value)
        image.orientation = orientation

        activeSegmenter.process(image) { [weak self, retainedSampleBuffer] mask, error in
            _ = retainedSampleBuffer
            guard let self = self else { return }

            defer {
                self.stateQueue.async {
                    self.isProcessing = false
                }
            }

            if let error = error {
                self.sendError(code: "SEGMENTATION_FAILED", message: error.localizedDescription)
                return
            }

            guard let mask = mask else {
                self.sendError(code: "SEGMENTATION_EMPTY", message: "ML Kit returned no segmentation mask.")
                return
            }

            self.emit(
                mask: mask,
                timestampMs: timestampMs,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )
        }
    }

    private func copySampleBuffer(_ sampleBuffer: CMSampleBuffer) throws -> CMSampleBuffer {
        guard let sourcePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw segmentationError("Input sample buffer has no image buffer.")
        }

        let copiedPixelBuffer = try copyPixelBuffer(sourcePixelBuffer)
        var formatDescription: CMVideoFormatDescription?
        var status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: copiedPixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard status == noErr, let formatDescription = formatDescription else {
            throw segmentationError("Could not create segmentation frame format: \(status).")
        }

        var timingInfo = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            decodeTimeStamp: CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
        )
        var copiedSampleBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: copiedPixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timingInfo,
            sampleBufferOut: &copiedSampleBuffer
        )
        guard status == noErr, let copiedSampleBuffer = copiedSampleBuffer else {
            throw segmentationError("Could not create copied segmentation sample buffer: \(status).")
        }

        return copiedSampleBuffer
    }

    private func copyPixelBuffer(_ sourcePixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(sourcePixelBuffer)
        let height = CVPixelBufferGetHeight(sourcePixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(sourcePixelBuffer)
        var copiedPixelBuffer: CVPixelBuffer?

        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        var status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            attributes as CFDictionary,
            &copiedPixelBuffer
        )
        guard status == kCVReturnSuccess, let copiedPixelBuffer = copiedPixelBuffer else {
            throw segmentationError("Could not allocate segmentation pixel buffer: \(status).")
        }

        status = CVPixelBufferLockBaseAddress(sourcePixelBuffer, .readOnly)
        guard status == kCVReturnSuccess else {
            throw segmentationError("Could not lock source segmentation pixel buffer: \(status).")
        }
        defer {
            CVPixelBufferUnlockBaseAddress(sourcePixelBuffer, .readOnly)
        }

        status = CVPixelBufferLockBaseAddress(copiedPixelBuffer, [])
        guard status == kCVReturnSuccess else {
            throw segmentationError("Could not lock copied segmentation pixel buffer: \(status).")
        }
        defer {
            CVPixelBufferUnlockBaseAddress(copiedPixelBuffer, [])
        }

        guard let sourceBaseAddress = CVPixelBufferGetBaseAddress(sourcePixelBuffer),
              let destinationBaseAddress = CVPixelBufferGetBaseAddress(copiedPixelBuffer) else {
            throw segmentationError("Segmentation pixel buffer has no base address.")
        }

        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(sourcePixelBuffer)
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(copiedPixelBuffer)
        let bytesPerRow = min(sourceBytesPerRow, destinationBytesPerRow)

        for row in 0..<height {
            memcpy(
                destinationBaseAddress.advanced(by: row * destinationBytesPerRow),
                sourceBaseAddress.advanced(by: row * sourceBytesPerRow),
                bytesPerRow
            )
        }

        return copiedPixelBuffer
    }

    private func segmentationError(_ message: String) -> NSError {
        NSError(
            domain: "SegmentationService",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func setupSegmenter() {
        if segmenter != nil { return }

        let options = SelfieSegmenterOptions()
        options.segmenterMode = .stream
        options.shouldEnableRawSizeMask = true
        segmenter = Segmenter.segmenter(options: options)
    }

    private func disposeSegmenter() {
        stateQueue.sync {
            isRunning = false
            isProcessing = false
            lastProcessedTimestampMs = Int.min
        }
        segmenter = nil
    }

    private func emit(mask: SegmentationMask,
                      timestampMs: Int,
                      imageWidth: Int,
                      imageHeight: Int) {
        let pixelBuffer = mask.buffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let totalPixels = width * height

        guard totalPixels > 0 else {
            sendError(code: "SEGMENTATION_BUFFER_EMPTY", message: "Segmentation mask has no pixels.")
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            sendError(code: "SEGMENTATION_BUFFER_EMPTY", message: "Segmentation mask has no base address.")
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var personPixels = 0
        var softPersonPixels = 0

        for row in 0..<height {
            let rowAddress = baseAddress.advanced(by: row * bytesPerRow)
                .assumingMemoryBound(to: Float32.self)
            for column in 0..<width {
                let confidence = rowAddress[column]
                if confidence >= pixelConfidenceThreshold {
                    personPixels += 1
                }
                if confidence >= softPixelConfidenceThreshold {
                    softPersonPixels += 1
                }
            }
        }

        let payload: [String: Any] = [
            "timestampMs": timestampMs,
            "imageWidth": imageWidth,
            "imageHeight": imageHeight,
            "personRatio": Double(personPixels) / Double(totalPixels),
            "softPersonRatio": Double(softPersonPixels) / Double(totalPixels),
        ]

        DispatchQueue.main.async {
            self.eventSink?(payload)
        }
    }

    private func sendError(code: String, message: String) {
        DispatchQueue.main.async {
            self.eventSink?(FlutterError(code: code, message: message, details: nil))
        }
    }
}
