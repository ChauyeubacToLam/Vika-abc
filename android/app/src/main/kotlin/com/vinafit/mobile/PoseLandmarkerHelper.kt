package com.vinafit.mobile

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import androidx.camera.core.ImageProxy
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.components.containers.Landmark
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import java.io.ByteArrayOutputStream
import java.util.concurrent.ConcurrentHashMap

class PoseLandmarkerHelper(
    context: Context,
    private val onResult: (Map<String, Any?>) -> Unit,
    private val onError: (String, String?) -> Unit,
) {
    private val appContext = context.applicationContext
    private var poseLandmarker: PoseLandmarker? = null
    private var lastSubmittedTimestampMs: Long = Long.MIN_VALUE
    private val pendingFrames = ConcurrentHashMap<Long, FramePayload>()

    init {
        setupPoseLandmarker()
    }

    fun setupPoseLandmarker() {
        clearPoseLandmarker()

        val baseOptions = BaseOptions.builder()
            .setModelAssetPath(MODEL_ASSET_NAME)
            .setDelegate(Delegate.CPU)
            .build()

        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumPoses(1)
            .setMinPoseDetectionConfidence(0.5f)
            .setMinPosePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setResultListener(this::returnLivestreamResult)
            .setErrorListener(this::returnLivestreamError)
            .build()

        poseLandmarker = PoseLandmarker.createFromOptions(appContext, options)
    }

    fun clearPoseLandmarker() {
        poseLandmarker?.close()
        poseLandmarker = null
        pendingFrames.clear()
        lastSubmittedTimestampMs = Long.MIN_VALUE
    }

    fun detectLiveStream(imageProxy: ImageProxy, isFrontCamera: Boolean) {
        var pendingTimestampMs: Long? = null

        try {
            val activeLandmarker = poseLandmarker ?: return
            val nextTimestampMs = imageProxy.imageInfo.timestamp / 1_000_000L
            if (nextTimestampMs <= lastSubmittedTimestampMs) {
                return
            }

            val nv21Bytes = imageProxyToNv21(imageProxy)
            val rawBitmap = nv21ToBitmap(nv21Bytes, imageProxy.width, imageProxy.height)
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees
            val rotatedBitmap = rotateBitmap(rawBitmap, rotationDegrees)
            if (rotatedBitmap !== rawBitmap) {
                rawBitmap.recycle()
            }

            val submittedTimestampMs = nextTimestampMs
            pendingTimestampMs = submittedTimestampMs
            pendingFrames[submittedTimestampMs] = FramePayload(
                frameBytes = nv21Bytes,
                frameWidth = imageProxy.width,
                frameHeight = imageProxy.height,
                imageWidth = rotatedBitmap.width,
                imageHeight = rotatedBitmap.height,
                rotationDegrees = rotationDegrees,
                isFrontCamera = isFrontCamera,
            )
            trimPendingFrames()

            val mpImage = BitmapImageBuilder(rotatedBitmap).build()
            lastSubmittedTimestampMs = submittedTimestampMs
            activeLandmarker.detectAsync(mpImage, submittedTimestampMs)
        } catch (exception: Exception) {
            pendingTimestampMs?.let { pendingFrames.remove(it) }
            onError("pose_landmarker_detection", exception.message)
        } finally {
            imageProxy.close()
        }
    }

    private fun returnLivestreamResult(result: PoseLandmarkerResult, input: MPImage) {
        val timestampMs = result.timestampMs()
        val framePayload = pendingFrames.remove(timestampMs)

        try {
            if (framePayload == null) {
                return
            }

            if (result.landmarks().isEmpty()) {
                onResult(framePayload.toEventPayload(timestampMs, emptyList(), emptyList()))
                return
            }

            val pose = result.landmarks().first()
            val worldPose = result.worldLandmarks().firstOrNull().orEmpty()

            val landmarkList = pose.mapIndexed { index, landmark ->
                landmarkToMap(index, landmark)
            }
            val worldLandmarkList = worldPose.mapIndexed { index, landmark ->
                worldLandmarkToMap(index, landmark)
            }

            onResult(framePayload.toEventPayload(timestampMs, landmarkList, worldLandmarkList))
        } catch (exception: Exception) {
            onError("pose_landmarker_result", exception.message)
        } finally {
            input.close()
        }
    }

    private fun returnLivestreamError(exception: RuntimeException) {
        onError("pose_landmarker_stream", exception.message)
    }

    private fun landmarkToMap(index: Int, landmark: NormalizedLandmark): Map<String, Any> {
        return mapOf(
            "type" to index,
            "x" to landmark.x(),
            "y" to landmark.y(),
            "z" to landmark.z(),
            "likelihood" to (landmark.visibility().orElse(0.0f)),
        )
    }

    private fun worldLandmarkToMap(index: Int, landmark: Landmark): Map<String, Any> {
        return mapOf(
            "type" to index,
            "x" to landmark.x(),
            "y" to landmark.y(),
            "z" to landmark.z(),
            "likelihood" to (landmark.visibility().orElse(0.0f)),
        )
    }

    private fun trimPendingFrames(maxEntries: Int = 4) {
        if (pendingFrames.size <= maxEntries) {
            return
        }

        val keysToDrop = pendingFrames.keys.toList().sorted().take(pendingFrames.size - maxEntries)
        for (key in keysToDrop) {
            pendingFrames.remove(key)
        }
    }

    private fun imageProxyToNv21(imageProxy: ImageProxy): ByteArray {
        val width = imageProxy.width
        val height = imageProxy.height
        val ySize = width * height
        val nv21 = ByteArray(ySize + (width * height / 2))

        copyPlane(
            plane = imageProxy.planes[0],
            width = width,
            height = height,
            output = nv21,
            outputOffset = 0,
            outputStride = 1,
        )
        copyPlane(
            plane = imageProxy.planes[2],
            width = width / 2,
            height = height / 2,
            output = nv21,
            outputOffset = ySize,
            outputStride = 2,
        )
        copyPlane(
            plane = imageProxy.planes[1],
            width = width / 2,
            height = height / 2,
            output = nv21,
            outputOffset = ySize + 1,
            outputStride = 2,
        )

        return nv21
    }

    private fun copyPlane(
        plane: ImageProxy.PlaneProxy,
        width: Int,
        height: Int,
        output: ByteArray,
        outputOffset: Int,
        outputStride: Int,
    ) {
        val buffer = plane.buffer
        buffer.rewind()

        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val rowData = ByteArray(rowStride)
        var outputIndex = outputOffset

        for (row in 0 until height) {
            val length = if (pixelStride == 1 && outputStride == 1) {
                width
            } else {
                ((width - 1) * pixelStride) + 1
            }

            buffer.get(rowData, 0, length)

            if (pixelStride == 1 && outputStride == 1) {
                System.arraycopy(rowData, 0, output, outputIndex, width)
                outputIndex += width
            } else {
                for (column in 0 until width) {
                    output[outputIndex] = rowData[column * pixelStride]
                    outputIndex += outputStride
                }
            }

            if (row < height - 1) {
                buffer.position(buffer.position() + rowStride - length)
            }
        }
    }

    private fun nv21ToBitmap(nv21Bytes: ByteArray, width: Int, height: Int): Bitmap {
        val yuvImage = YuvImage(nv21Bytes, ImageFormat.NV21, width, height, null)
        val outputStream = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, width, height), 95, outputStream)
        val jpegBytes = outputStream.toByteArray()

        return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
            ?: throw IllegalStateException("Failed to decode camera frame bitmap.")
    }

    private fun rotateBitmap(bitmap: Bitmap, rotationDegrees: Int): Bitmap {
        if (rotationDegrees == 0) {
            return bitmap
        }

        val matrix = Matrix().apply {
            postRotate(rotationDegrees.toFloat())
        }

        return Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true,
        )
    }

    private data class FramePayload(
        val frameBytes: ByteArray,
        val frameWidth: Int,
        val frameHeight: Int,
        val imageWidth: Int,
        val imageHeight: Int,
        val rotationDegrees: Int,
        val isFrontCamera: Boolean,
    ) {
        fun toEventPayload(
            timestampMs: Long,
            landmarks: List<Map<String, Any>>,
            worldLandmarks: List<Map<String, Any>>,
        ): Map<String, Any?> {
            return mapOf(
                "landmarks" to landmarks,
                "worldLandmarks" to worldLandmarks,
                "imageWidth" to imageWidth,
                "imageHeight" to imageHeight,
                "frameWidth" to frameWidth,
                "frameHeight" to frameHeight,
                "frameBytes" to frameBytes,
                "rotationDegrees" to rotationDegrees,
                "isFrontCamera" to isFrontCamera,
                "timestampMs" to timestampMs,
            )
        }
    }

    companion object {
        private const val MODEL_ASSET_NAME = "pose_landmarker_lite.task"
    }
}
