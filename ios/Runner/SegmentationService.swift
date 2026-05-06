import Foundation
import AVFoundation
import Darwin
import Flutter
import UIKit
import MLKitSegmentationCommon
import MLKitSegmentationSelfie
import MLKitVision

final class SegmentationService: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private let segmenter: Segmenter

    override init() {
        let options = SelfieSegmenterOptions()
        options.segmenterMode = .stream
        options.shouldEnableRawSizeMask = false
        segmenter = Segmenter.segmenter(options: options)

        super.init()
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
                orientation: UIImage.Orientation = .up) {
        let image = VisionImage(buffer: sampleBuffer)
        image.orientation = orientation

        segmenter.process(image) { [weak self] mask, error in
            guard let self = self else { return }

            if let error = error {
                self.sendError(code: "SEGMENTATION_FAILED", message: error.localizedDescription)
                return
            }

            guard let mask = mask else {
                self.sendError(code: "SEGMENTATION_EMPTY", message: "ML Kit returned no segmentation mask.")
                return
            }

            self.emit(mask: mask, timestampMs: timestampMs)
        }
    }

    private func emit(mask: SegmentationMask, timestampMs: Int) {
        let pixelBuffer = mask.buffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let rowByteCount = width * MemoryLayout<Float32>.size

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            sendError(code: "SEGMENTATION_BUFFER_EMPTY", message: "Segmentation mask has no base address.")
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var maskData = Data(count: rowByteCount * height)

        maskData.withUnsafeMutableBytes { outputBuffer in
            guard let outputBaseAddress = outputBuffer.baseAddress else { return }

            for row in 0..<height {
                let source = baseAddress.advanced(by: row * bytesPerRow)
                let destination = outputBaseAddress.advanced(by: row * rowByteCount)
                memcpy(destination, source, rowByteCount)
            }
        }

        let payload: [String: Any] = [
            "maskWidth": width,
            "maskHeight": height,
            "maskData": FlutterStandardTypedData(bytes: maskData),
            "timestampMs": timestampMs,
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
