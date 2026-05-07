package com.vikavn.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var poseLandmarkerPlugin: PoseLandmarkerPlugin? = null
    private var segmentationHelper: SelfieSegmentationHelper? = null
    private var segmentationMethodChannel: MethodChannel? = null
    private var segmentationEventChannel: EventChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        segmentationHelper = SelfieSegmentationHelper()
        poseLandmarkerPlugin = PoseLandmarkerPlugin(this, flutterEngine, segmentationHelper)
        segmentationMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SEGMENTATION_METHOD_CHANNEL_NAME,
        ).also { channel ->
            channel.setMethodCallHandler(segmentationHelper)
        }
        segmentationEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SEGMENTATION_EVENT_CHANNEL_NAME,
        ).also { channel ->
            channel.setStreamHandler(segmentationHelper)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        segmentationMethodChannel?.setMethodCallHandler(null)
        segmentationMethodChannel = null
        segmentationEventChannel?.setStreamHandler(null)
        segmentationEventChannel = null
        segmentationHelper?.close()
        segmentationHelper = null
        poseLandmarkerPlugin?.dispose()
        poseLandmarkerPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val SEGMENTATION_METHOD_CHANNEL_NAME = "com.vikavn.app/segmentation"
        private const val SEGMENTATION_EVENT_CHANNEL_NAME = "com.vikavn.app/segmentation_stream"
    }
}
