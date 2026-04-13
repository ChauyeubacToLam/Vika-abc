package com.vinafit.mobile

import android.annotation.SuppressLint
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.util.Size
import android.view.Surface
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
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PoseLandmarkerPlugin(
    private val activity: FlutterActivity,
    flutterEngine: FlutterEngine,
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
    private var useFrontCamera = false
    private var detectionEnabled = true

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "dispose" -> {
                disposeResources(releaseTexture = true)
                result.success(null)
            }
            "switchCamera" -> {
                val previousLens = useFrontCamera
                try {
                    useFrontCamera = !useFrontCamera
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
        useFrontCamera = call.argument<Boolean>("useFrontCamera") ?: false
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

        provider.unbindAll()

        val previewUseCase = Preview.Builder()
            .setTargetResolution(Size(TARGET_WIDTH, TARGET_HEIGHT))
            .build()
            .also { configuredPreview ->
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
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { configuredAnalysis ->
                configuredAnalysis.setAnalyzer(executor) { imageProxy ->
                    if (!detectionEnabled) {
                        imageProxy.close()
                        return@setAnalyzer
                    }

                    helper.detectLiveStream(
                        imageProxy = imageProxy,
                        isFrontCamera = useFrontCamera,
                    )
                }
            }

        preview = previewUseCase
        imageAnalysis = analysisUseCase

        provider.bindToLifecycle(activity, cameraSelector, previewUseCase, analysisUseCase)
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
        private const val METHOD_CHANNEL_NAME = "com.vinafit.mobile/pose_landmarker"
        private const val EVENT_CHANNEL_NAME = "com.vinafit.mobile/pose_landmarker_stream"
        private const val TARGET_WIDTH = 640
        private const val TARGET_HEIGHT = 480
    }
}
