package com.vikavn.app

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Size
import android.view.Surface
import androidx.camera.core.ImageProxy
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PoseLandmarkerPlugin(
    private val activity: FlutterActivity,
    flutterEngine: FlutterEngine,
    private val segmentationHelper: SelfieSegmentationHelper?,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methodChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        METHOD_CHANNEL_NAME,
    )
    private val eventChannel = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        EVENT_CHANNEL_NAME,
    )
    private val textureRegistry: TextureRegistry = flutterEngine.renderer
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraExecutor: ExecutorService? = null
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var poseLandmarkerHelper: PoseLandmarkerHelper? = null
    private var useFrontCamera = true
    @Volatile private var currentOrientationCode: String? = null
    @Volatile private var currentOrientationIsFrontCamera = true
    @Volatile private var currentTargetRotation: Int? = null
    private var rotationLogFrameCount = 0
    private var detectionEnabled = true

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "setOrientation" -> {
                val orientation = call.argument<String>("orientation")
                if (orientation == null) {
                    result.error("pose_landmarker_orientation", "Missing orientation.", null)
                    return
                }
                val isFrontCamera = call.argument<Boolean>("isFrontCamera") ?: useFrontCamera
                setOrientation(orientation, isFrontCamera)
                result.success(null)
            }
            "dispose" -> {
                disposeResources(releaseTexture = true)
                result.success(null)
            }
            "switchCamera" -> {
                val previousLens = useFrontCamera
                try {
                    useFrontCamera = !useFrontCamera
                    currentOrientationCode?.let { orientation ->
                        setOrientation(orientation, useFrontCamera)
                    }
                    bindCameraUseCases()
                    result.success(null)
                } catch (exception: Exception) {
                    useFrontCamera = previousLens
                    result.error("pose_landmarker_switch_camera", exception.message, null)
                }
            }
            "startDetection" -> {
                detectionEnabled = true
                result.success(null)
            }
            "stopDetection" -> {
                detectionEnabled = false
                result.success(null)
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

    fun dispose() {
        disposeResources(releaseTexture = true)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        useFrontCamera = call.argument<Boolean>("useFrontCamera") ?: true
        applyInitialOrientation(call)
        detectionEnabled = true

        try {
            ensureRuntimeSupport()

            if (textureEntry == null) {
                textureEntry = textureRegistry.createSurfaceTexture()
            }
            if (cameraExecutor == null || cameraExecutor?.isShutdown == true) {
                cameraExecutor = Executors.newSingleThreadExecutor()
            }
            if (poseLandmarkerHelper == null) {
                poseLandmarkerHelper = PoseLandmarkerHelper(
                    context = activity.applicationContext,
                    onResult = ::emitResult,
                    onError = ::emitError,
                )
            }
            poseLandmarkerHelper?.setOrientation(
                currentOrientationCode,
                currentOrientationIsFrontCamera,
            )
            segmentationHelper?.setOrientation(
                currentOrientationCode,
                currentOrientationIsFrontCamera,
            )

            val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
            cameraProviderFuture.addListener(
                {
                    try {
                        cameraProvider = cameraProviderFuture.get()
                        bindCameraUseCases()
                        result.success(textureEntry?.id())
                    } catch (exception: Exception) {
                        result.error("pose_landmarker_init", exception.message, null)
                    }
                },
                ContextCompat.getMainExecutor(activity),
            )
        } catch (error: UnsatisfiedLinkError) {
            disposeResources(releaseTexture = false)
            result.error("pose_landmarker_init", errorMessageForRuntime(error), null)
        } catch (exception: Exception) {
            disposeResources(releaseTexture = false)
            result.error("pose_landmarker_init", exception.message, null)
        }
    }

    private fun applyInitialOrientation(call: MethodCall) {
        val initialOrientation = call.argument<String>("initialOrientation")
        if (initialOrientation == null) {
            currentOrientationCode = null
            currentOrientationIsFrontCamera = useFrontCamera
            currentTargetRotation = null
            poseLandmarkerHelper?.setOrientation(null, useFrontCamera)
            segmentationHelper?.setOrientation(null, useFrontCamera)
            return
        }

        val isFrontCamera = call.argument<Boolean>("isFrontCamera") ?: useFrontCamera
        setOrientation(initialOrientation, isFrontCamera)
    }

    private fun setOrientation(orientation: String, isFrontCamera: Boolean) {
        currentOrientationCode = orientation
        currentOrientationIsFrontCamera = isFrontCamera
        currentTargetRotation = targetRotationForOrientation(orientation)
        currentTargetRotation?.let { targetRotation ->
            preview?.targetRotation = targetRotation
            imageAnalysis?.targetRotation = targetRotation
        }
        poseLandmarkerHelper?.setOrientation(orientation, isFrontCamera)
        segmentationHelper?.setOrientation(orientation, isFrontCamera)
    }

    private fun ensureRuntimeSupport() {
        val supportedAbis = Build.SUPPORTED_ABIS?.toList().orEmpty()
        if (supportedAbis.any { it.equals("x86_64", ignoreCase = true) }) {
            throw IllegalStateException(
                "MediaPipe Pose Landmarker is not available on x86_64 Android emulators. Use a physical ARM phone or an ARM emulator image."
            )
        }
    }

    private fun errorMessageForRuntime(error: Throwable): String {
        val message = error.message.orEmpty()
        if (message.contains("libmediapipe_tasks_vision_jni.so")) {
            return "MediaPipe Pose Landmarker native library could not be loaded on this device. Use a physical ARM phone or an ARM emulator image."
        }
        return message.ifBlank { "Failed to initialize MediaPipe Pose Landmarker." }
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: throw IllegalStateException("Camera provider is not ready.")
        val surfaceTextureEntry =
            textureEntry ?: throw IllegalStateException("Flutter texture is not initialized.")
        val executor = cameraExecutor ?: throw IllegalStateException("Camera executor is not ready.")
        val helper =
            poseLandmarkerHelper ?: throw IllegalStateException("Pose landmarker helper is not initialized.")

        val cameraSelector = resolveCameraSelector(provider)
        currentOrientationIsFrontCamera = useFrontCamera
        poseLandmarkerHelper?.setOrientation(currentOrientationCode, useFrontCamera)
        segmentationHelper?.setOrientation(currentOrientationCode, useFrontCamera)

        provider.unbindAll()

        val previewUseCase = Preview.Builder()
            .setTargetResolution(Size(TARGET_WIDTH, TARGET_HEIGHT))
            .build()
            .also { configuredPreview ->
                currentTargetRotation?.let { configuredPreview.targetRotation = it }
                configuredPreview.setSurfaceProvider { request ->
                    val surfaceTexture = surfaceTextureEntry.surfaceTexture()
                    surfaceTexture.setDefaultBufferSize(
                        request.resolution.width,
                        request.resolution.height,
                    )

                    val surface = Surface(surfaceTexture)
                    previewSurface = surface

                    request.provideSurface(surface, executor) {
                        if (previewSurface === surface) {
                            previewSurface = null
                        }
                        surface.release()
                    }
                }
            }

        val analysisUseCase = ImageAnalysis.Builder()
            .setTargetResolution(Size(TARGET_WIDTH, TARGET_HEIGHT))
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { configuredAnalysis ->
                currentTargetRotation?.let { configuredAnalysis.targetRotation = it }
                configuredAnalysis.setAnalyzer(executor) { imageProxy ->
                    if (!detectionEnabled) {
                        imageProxy.close()
                        return@setAnalyzer
                    }

                    analyzeFrame(
                        imageProxy = imageProxy,
                        helper = helper,
                    )
                }
            }

        preview = previewUseCase
        imageAnalysis = analysisUseCase

        provider.bindToLifecycle(activity, cameraSelector, previewUseCase, analysisUseCase)
    }

    private fun analyzeFrame(
        imageProxy: ImageProxy,
        helper: PoseLandmarkerHelper,
    ) {
        try {
            val timestampMs = imageProxy.imageInfo.timestamp / 1_000_000L
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees
            val rawBitmap = rgbaImageProxyToBitmap(imageProxy)
            val rotationStartedNs = SystemClock.elapsedRealtimeNanos()
            val processedBitmap = rotateBitmap(rawBitmap, rotationDegrees)
            val rotationDurationMs =
                (SystemClock.elapsedRealtimeNanos() - rotationStartedNs) / 1_000_000.0
            logRotationDuration(rotationDegrees, rotationDurationMs)
            if (processedBitmap !== rawBitmap) {
                rawBitmap.recycle()
            }

            val frameOwner = SharedBitmapFrame(processedBitmap)

            frameOwner.retain()
            val segmentationRelease = frameOwner.releaseCallback()
            val segmentationStarted = segmentationHelper?.detectLiveStream(
                bitmap = processedBitmap,
                timestampMs = timestampMs,
                onComplete = segmentationRelease,
            ) ?: false
            if (!segmentationStarted) {
                segmentationRelease()
            }

            frameOwner.retain()
            val poseRelease = frameOwner.releaseCallback()
            val poseStarted = helper.detectLiveStream(
                bitmap = processedBitmap,
                timestampMs = timestampMs,
                frameWidth = imageProxy.width,
                frameHeight = imageProxy.height,
                rotationDegrees = rotationDegrees,
                rotationDurationMs = rotationDurationMs,
                isFrontCamera = useFrontCamera,
                onComplete = poseRelease,
            )
            if (!poseStarted) {
                poseRelease()
            }

            frameOwner.release()
        } catch (exception: Exception) {
            emitError("pose_landmarker_frame", exception.message)
        } finally {
            imageProxy.close()
        }
    }

    private fun rgbaImageProxyToBitmap(imageProxy: ImageProxy): Bitmap {
        val plane = imageProxy.planes.firstOrNull()
            ?: throw IllegalStateException("RGBA camera frame has no image plane.")
        val width = imageProxy.width
        val height = imageProxy.height
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * width
        val bitmapWidth = width + rowPadding / pixelStride

        plane.buffer.rewind()
        val paddedBitmap = Bitmap.createBitmap(bitmapWidth, height, Bitmap.Config.ARGB_8888)
        paddedBitmap.copyPixelsFromBuffer(plane.buffer)

        if (bitmapWidth == width) {
            return paddedBitmap
        }

        val croppedBitmap = Bitmap.createBitmap(paddedBitmap, 0, 0, width, height)
        paddedBitmap.recycle()
        return croppedBitmap
    }

    private fun rotateBitmap(bitmap: Bitmap, rotationDegrees: Int): Bitmap {
        if (rotationDegrees == 0) {
            return bitmap
        }

        val matrix = Matrix().apply {
            postRotate(rotationDegrees.toFloat())
            // Prompt 3 (Revised), Option A: do not mirror front-camera frames here.
            // iOS Pose Landmarker cannot consume mirrored orientation tokens, so both
            // platforms intentionally keep un-mirrored inference input and let the
            // existing painter mirror only the visual preview/skeleton.
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

    private fun logRotationDuration(rotationDegrees: Int, rotationDurationMs: Double) {
        if (currentOrientationCode == null && rotationDurationMs < ROTATION_SLOW_FRAME_MS) {
            return
        }

        rotationLogFrameCount = (rotationLogFrameCount + 1) % ROTATION_LOG_SAMPLE_RATE
        if (rotationLogFrameCount != 0 && rotationDurationMs < ROTATION_SLOW_FRAME_MS) {
            return
        }

        Log.d(
            TAG,
            "rotationDegrees=$rotationDegrees " +
                "rotationDurationMs=${"%.3f".format(rotationDurationMs)} " +
                "orientation=${currentOrientationCode ?: "cameraX"} " +
                "isFrontCamera=$useFrontCamera",
        )
    }

    private class SharedBitmapFrame(private val bitmap: Bitmap) {
        private val references = AtomicInteger(1)

        fun retain() {
            references.incrementAndGet()
        }

        fun release() {
            if (references.decrementAndGet() == 0 && !bitmap.isRecycled) {
                bitmap.recycle()
            }
        }

        fun releaseCallback(): () -> Unit {
            val didRelease = AtomicBoolean(false)
            return {
                if (didRelease.compareAndSet(false, true)) {
                    release()
                }
            }
        }
    }

    private fun resolveCameraSelector(provider: ProcessCameraProvider): CameraSelector {
        val preferredSelector = if (useFrontCamera) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
        if (provider.hasCameraSafely(preferredSelector)) {
            return preferredSelector
        }

        val fallbackSelector = if (useFrontCamera) {
            CameraSelector.DEFAULT_BACK_CAMERA
        } else {
            CameraSelector.DEFAULT_FRONT_CAMERA
        }
        if (provider.hasCameraSafely(fallbackSelector)) {
            useFrontCamera = !useFrontCamera
            return fallbackSelector
        }

        throw IllegalStateException("No compatible camera is available on this device.")
    }

    private fun ProcessCameraProvider.hasCameraSafely(selector: CameraSelector): Boolean {
        return try {
            hasCamera(selector)
        } catch (_: Exception) {
            false
        }
    }

    private fun emitResult(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private fun emitError(code: String, message: String?) {
        mainHandler.post {
            eventSink?.error(code, message, null)
        }
    }

    private fun disposeResources(releaseTexture: Boolean) {
        detectionEnabled = false
        imageAnalysis?.clearAnalyzer()
        cameraProvider?.unbindAll()
        preview = null
        imageAnalysis = null
        previewSurface?.release()
        previewSurface = null

        poseLandmarkerHelper?.clearPoseLandmarker()
        poseLandmarkerHelper = null

        cameraExecutor?.shutdown()
        cameraExecutor = null

        if (releaseTexture) {
            textureEntry?.release()
            textureEntry = null
        }
    }

    companion object {
        private const val TAG = "PoseLandmarkerPlugin"
        private const val METHOD_CHANNEL_NAME = "com.vikavn.app/pose_landmarker"
        private const val EVENT_CHANNEL_NAME = "com.vikavn.app/pose_landmarker_stream"
        private const val ROTATION_LOG_SAMPLE_RATE = 30
        private const val ROTATION_SLOW_FRAME_MS = 12.0
        // 16:9 keeps the wide exercise framing while avoiding the per-frame 720p
        // bitmap allocation/rotation cost on mid and low-range Android phones.
        // CameraX picks the closest supported size when 960x540 is unavailable.
        private const val TARGET_WIDTH = 960
        private const val TARGET_HEIGHT = 540

        private fun targetRotationForOrientation(orientation: String): Int {
            return when (orientation) {
                "landscapeLeft" -> Surface.ROTATION_90
                "portraitUpsideDown" -> Surface.ROTATION_180
                "landscapeRight" -> Surface.ROTATION_270
                else -> Surface.ROTATION_0
            }
        }
    }
}
