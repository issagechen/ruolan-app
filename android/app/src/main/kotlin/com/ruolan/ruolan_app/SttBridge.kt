package com.ruolan.ruolan_app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SttBridge(private val activity: Activity, flutterEngine: FlutterEngine) {
    companion object {
        private const val CHANNEL = "com.ruolan.stt"
    }

    private var pendingResult: MethodChannel.Result? = null
    private var recognizer: SpeechRecognizer? = null

    init {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(SpeechRecognizer.isRecognitionAvailable(activity))
                    "listen" -> startListening(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startListening(result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            result.success(null)
            return
        }
        pendingResult = result
        try {
            recognizer?.destroy()
            recognizer = SpeechRecognizer.createSpeechRecognizer(activity).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(p: Bundle?) {}
                    override fun onBeginningOfSpeech() {}
                    override fun onRmsChanged(r: Float) {}
                    override fun onBufferReceived(b: ByteArray?) {}
                    override fun onEndOfSpeech() {}
                    override fun onError(e: Int) { finish(null) }
                    override fun onResults(r: Bundle?) {
                        val matches = r?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        finish(matches?.firstOrNull())
                    }
                    override fun onPartialResults(r: Bundle?) {}
                    override fun onEvent(t: Int, p: Bundle?) {}
                })
                startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                })
            }
        } catch (e: Exception) {
            pendingResult = null
            result.success(null)
        }
    }

    private fun finish(text: String?) {
        val r = pendingResult
        pendingResult = null
        r?.success(text)
    }

    fun destroy() { recognizer?.destroy(); recognizer = null }
}
