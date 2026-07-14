package com.ruolan.ruolan_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var llamaBridge: com.ruolan.ruolan_app.LlamaBridge? = null
    private var sttBridge: com.ruolan.ruolan_app.SttBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        llamaBridge = com.ruolan.ruolan_app.LlamaBridge(applicationContext, flutterEngine)
        sttBridge = com.ruolan.ruolan_app.SttBridge(this, flutterEngine)
    }

    override fun onDestroy() {
        sttBridge?.destroy()
        llamaBridge?.destroy()
        super.onDestroy()
    }
}
