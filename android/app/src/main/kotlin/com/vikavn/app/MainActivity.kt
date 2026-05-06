package com.vikavn.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var poseLandmarkerPlugin: PoseLandmarkerPlugin? = null
    private var segmentationHelper: SelfieSegmentationHelper? = null
    private var segmentationEventChannel: EventChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        poseLandmarkerPlugin = PoseLandmarkerPlugin(this, flutterEngine)
        segmentationHelper = SelfieSegmentationHelper()
        segmentationEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SEGMENTATION_EVENT_CHANNEL_NAME,
        ).also { channel ->
            channel.setStreamHandler(segmentationHelper)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        segmentationEventChannel?.setStreamHandler(null)
        segmentationEventChannel = null
        segmentationHelper?.close()
        segmentationHelper = null
        poseLandmarkerPlugin?.dispose()
        poseLandmarkerPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        private const val SEGMENTATION_EVENT_CHANNEL_NAME = "com.vikavn.app/segmentation"
    }
}
