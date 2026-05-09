package com.vikavn.app

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.SegmentationMask
import com.google.mlkit.vision.segmentation.Segmenter
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/*
 * Native selfie segmentation channel contract.
 *
 * MethodChannel("com.vikavn.app/segmentation"):
 * - initialize({ pixelConfidenceThreshold?, softPixelConfidenceThreshold?,
 *                minProcessIntervalMs? }) -> { success: true }
 * - start() -> { success: true }
 * - stop() -> { success: true }
 * - requestSample() -> { success: true }
 * - dispose() -> { success: true }
 *
 * EventChannel("com.vikavn.app/segmentation_stream") emits:
 * {
 *   timestampMs: Long,
 *   imageWidth: Int,
 *   imageHeight: Int,
 *   personRatio: Double,
 *   softPersonRatio: Double
 * }
 *
 * The pose camera pipeline owns frames and calls detectLiveStream(). Raw masks
 * and camera bytes never cross the Flutter platform channel.
 */
class SelfieSegmentationHelper : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var segmenter: Segmenter? = null
    private var eventSink: EventChannel.EventSink? = null
    @Volatile private var isRunning = false
    @Volatile private var isProcessing = false
    @Volatile private var lastProcessedTimestampMs = Long.MIN_VALUE
    @Volatile private var pixelConfidenceThreshold = DEFAULT_PIXEL_CONFIDENCE_THRESHOLD
    @Volatile private var softPixelConfidenceThreshold = DEFAULT_SOFT_PIXEL_CONFIDENCE_THRESHOLD
    @Volatile private var minProcessIntervalMs = DEFAULT_MIN_PROCESS_INTERVAL_MS
    @Volatile private var bypassThrottleOnce = false
    @Volatile private var currentOrientationCode: String? = null
    @Volatile private var currentOrientationIsFrontCamera = false

    init {
        setupSegmenter()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                pixelConfidenceThreshold =
                    (call.argument<Double>("pixelConfidenceThreshold") ?: pixelConfidenceThreshold)
                        .toFloat()
                softPixelConfidenceThreshold =
                    (call.argument<Double>("softPixelConfidenceThreshold")
                        ?: softPixelConfidenceThreshold).toFloat()
                minProcessIntervalMs =
                    call.argument<Int>("minProcessIntervalMs") ?: minProcessIntervalMs
                setOrientation(
                    call.argument<String>("initialOrientation"),
                    call.argument<Boolean>("isFrontCamera") ?: currentOrientationIsFrontCamera,
                )
                setupSegmenter()
                result.success(mapOf("success" to true))
            }
            "start" -> {
                isRunning = true
                result.success(mapOf("success" to true))
            }
            "stop" -> {
                isRunning = false
                result.success(mapOf("success" to true))
            }
            "requestSample" -> {
                requestSample()
                result.success(mapOf("success" to true))
            }
            "setOrientation" -> {
                val orientation = call.argument<String>("orientation")
                if (orientation == null) {
                    result.error("segmentation_orientation", "Missing orientation.", null)
                    return
                }
                setOrientation(
                    orientation,
                    call.argument<Boolean>("isFrontCamera") ?: currentOrientationIsFrontCamera,
                )
                result.success(mapOf("success" to true))
            }
            "dispose" -> {
                disposeSegmenter()
                result.success(mapOf("success" to true))
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun detectLiveStream(
        bitmap: Bitmap,
        timestampMs: Long,
        onComplete: () -> Unit,
    ): Boolean {
        if (!isRunning || isProcessing) {
            return false
        }

        val activeSegmenter = segmenter ?: return false
        if (!shouldProcess(timestampMs)) {
            return false
        }

        isProcessing = true

        val inputImage = InputImage.fromBitmap(bitmap, 0)
        return try {
            activeSegmenter.process(inputImage)
                .addOnSuccessListener { mask ->
                    emitResult(mask, timestampMs, bitmap.width, bitmap.height)
                }
                .addOnFailureListener { exception ->
                    emitError("segmentation_failed", exception.message)
                }
                .addOnCompleteListener {
                    isProcessing = false
                    onComplete()
                }
            true
        } catch (exception: Exception) {
            isProcessing = false
            emitError("segmentation_failed", exception.message)
            false
        }
    }

    fun requestSample() {
        bypassThrottleOnce = true
    }

    fun setOrientation(orientation: String?, isFrontCamera: Boolean) {
        currentOrientationCode = orientation
        currentOrientationIsFrontCamera = isFrontCamera
    }

    fun close() {
        disposeSegmenter()
        eventSink = null
    }

    private fun setupSegmenter() {
        if (segmenter != null) {
            return
        }

        val options = SelfieSegmenterOptions.Builder()
            .setDetectorMode(SelfieSegmenterOptions.STREAM_MODE)
            .enableRawSizeMask()
            .build()

        segmenter = Segmentation.getClient(options)
    }

    private fun disposeSegmenter() {
        isRunning = false
        isProcessing = false
        lastProcessedTimestampMs = Long.MIN_VALUE
        bypassThrottleOnce = false
        segmenter?.close()
        segmenter = null
    }

    private fun shouldProcess(nowMs: Long): Boolean {
        if (bypassThrottleOnce) {
            bypassThrottleOnce = false
            lastProcessedTimestampMs = nowMs
            return true
        }

        if (
            lastProcessedTimestampMs != Long.MIN_VALUE &&
            nowMs - lastProcessedTimestampMs < minProcessIntervalMs
        ) {
            return false
        }

        lastProcessedTimestampMs = nowMs
        return true
    }

    private fun emitResult(
        mask: SegmentationMask,
        timestampMs: Long,
        imageWidth: Int,
        imageHeight: Int,
    ) {
        val totalPixels = mask.width * mask.height
        if (totalPixels <= 0) {
            emitError("segmentation_empty", "ML Kit returned an empty segmentation mask.")
            return
        }

        val maskBuffer = mask.buffer.duplicate()
        maskBuffer.rewind()

        var personPixels = 0
        var softPersonPixels = 0
        repeat(totalPixels) {
            val confidence = maskBuffer.float
            if (confidence >= pixelConfidenceThreshold) {
                personPixels += 1
            }
            if (confidence >= softPixelConfidenceThreshold) {
                softPersonPixels += 1
            }
        }

        val payload = mapOf(
            "timestampMs" to timestampMs,
            "imageWidth" to imageWidth,
            "imageHeight" to imageHeight,
            "personRatio" to personPixels.toDouble() / totalPixels.toDouble(),
            "softPersonRatio" to softPersonPixels.toDouble() / totalPixels.toDouble(),
            "orientation" to currentOrientationCode,
            "isFrontCamera" to currentOrientationIsFrontCamera,
        )

        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private fun emitError(code: String, message: String?) {
        mainHandler.post {
            eventSink?.error(code, message, null)
        }
    }

    companion object {
        private const val DEFAULT_PIXEL_CONFIDENCE_THRESHOLD = 0.92f
        private const val DEFAULT_SOFT_PIXEL_CONFIDENCE_THRESHOLD = 0.55f
        private const val DEFAULT_MIN_PROCESS_INTERVAL_MS = 140
    }
}
