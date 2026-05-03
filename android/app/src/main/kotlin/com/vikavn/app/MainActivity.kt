package com.vikavn.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var poseLandmarkerPlugin: PoseLandmarkerPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        poseLandmarkerPlugin = PoseLandmarkerPlugin(this, flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        poseLandmarkerPlugin?.dispose()
        poseLandmarkerPlugin = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
