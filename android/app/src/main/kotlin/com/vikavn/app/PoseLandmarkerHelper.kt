package com.vikavn.app

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.components.containers.Landmark
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
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
        pendingFrames.values.forEach { it.onComplete() }
        pendingFrames.clear()
        lastSubmittedTimestampMs = Long.MIN_VALUE
    }

    fun detectLiveStream(
        bitmap: Bitmap,
        timestampMs: Long,
        frameWidth: Int,
        frameHeight: Int,
        rotationDegrees: Int,
        isFrontCamera: Boolean,
        onComplete: () -> Unit,
    ): Boolean {
        var pendingTimestampMs: Long? = null

        try {
            val activeLandmarker = poseLandmarker ?: return false
            if (timestampMs <= lastSubmittedTimestampMs) {
                return false
            }

            val submittedTimestampMs = timestampMs
            pendingTimestampMs = submittedTimestampMs
            pendingFrames[submittedTimestampMs] = FramePayload(
                frameWidth = frameWidth,
                frameHeight = frameHeight,
                imageWidth = bitmap.width,
                imageHeight = bitmap.height,
                rotationDegrees = rotationDegrees,
                isFrontCamera = isFrontCamera,
                onComplete = onComplete,
            )
            trimPendingFrames()

            val mpImage = BitmapImageBuilder(bitmap).build()
            lastSubmittedTimestampMs = submittedTimestampMs
            activeLandmarker.detectAsync(mpImage, submittedTimestampMs)
            return true
        } catch (exception: Exception) {
            pendingTimestampMs?.let { timestamp ->
                pendingFrames.remove(timestamp)?.onComplete()
            }
            onError("pose_landmarker_detection", exception.message)
            return false
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
            framePayload?.onComplete()
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
            "presence" to landmark.presence()
                .orElse(landmark.visibility().orElse(0.0f)),
            "visibility" to landmark.visibility()
                .orElse(landmark.presence().orElse(0.0f)),
            "likelihood" to landmark.visibility()
                .orElse(landmark.presence().orElse(0.0f)),
        )
    }

    private fun worldLandmarkToMap(index: Int, landmark: Landmark): Map<String, Any> {
        return mapOf(
            "type" to index,
            "x" to landmark.x(),
            "y" to landmark.y(),
            "z" to landmark.z(),
            "presence" to landmark.presence()
                .orElse(landmark.visibility().orElse(0.0f)),
            "visibility" to landmark.visibility()
                .orElse(landmark.presence().orElse(0.0f)),
            "likelihood" to landmark.visibility()
                .orElse(landmark.presence().orElse(0.0f)),
        )
    }

    private fun trimPendingFrames(maxEntries: Int = 4) {
        if (pendingFrames.size <= maxEntries) {
            return
        }

        val keysToDrop = pendingFrames.keys.toList().sorted().take(pendingFrames.size - maxEntries)
        for (key in keysToDrop) {
            pendingFrames.remove(key)?.onComplete()
        }
    }

    private data class FramePayload(
        val frameWidth: Int,
        val frameHeight: Int,
        val imageWidth: Int,
        val imageHeight: Int,
        val rotationDegrees: Int,
        val isFrontCamera: Boolean,
        val onComplete: () -> Unit,
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
