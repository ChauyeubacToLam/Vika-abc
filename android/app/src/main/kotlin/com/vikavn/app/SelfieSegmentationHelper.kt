package com.vikavn.app

import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.SegmentationMask
import com.google.mlkit.vision.segmentation.Segmenter
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import io.flutter.plugin.common.EventChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

class SelfieSegmentationHelper : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val segmenter: Segmenter
    private var eventSink: EventChannel.EventSink? = null

    init {
        val options = SelfieSegmenterOptions.Builder()
            .setDetectorMode(SelfieSegmenterOptions.STREAM_MODE)
            .build()

        segmenter = Segmentation.getClient(options)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun detectLiveStream(inputImage: InputImage, timestampMs: Long) {
        segmenter.process(inputImage)
            .addOnSuccessListener { mask ->
                emitResult(mask, timestampMs)
            }
            .addOnFailureListener { exception ->
                emitError("segmentation_failed", exception.message)
            }
    }

    fun close() {
        segmenter.close()
        eventSink = null
    }

    private fun emitResult(mask: SegmentationMask, timestampMs: Long) {
        val maskWidth = mask.width
        val maskHeight = mask.height
        val maskData = copyFloatMaskToLittleEndianBytes(mask)

        val payload = mapOf(
            "maskWidth" to maskWidth,
            "maskHeight" to maskHeight,
            "maskData" to maskData,
            "timestampMs" to timestampMs,
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

    private fun copyFloatMaskToLittleEndianBytes(mask: SegmentationMask): ByteArray {
        val inputBuffer = mask.buffer.duplicate()
        inputBuffer.rewind()

        val outputBytes = ByteArray(mask.width * mask.height * FLOAT_BYTE_COUNT)
        val outputBuffer = ByteBuffer.wrap(outputBytes).order(ByteOrder.LITTLE_ENDIAN)

        repeat(mask.width * mask.height) {
            outputBuffer.putFloat(inputBuffer.getFloat())
        }

        return outputBytes
    }

    companion object {
        private const val FLOAT_BYTE_COUNT = 4
    }
}
