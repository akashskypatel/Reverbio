package com.akashskypatel.reverbio

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    companion object {
        private val AUDIO_CHANNEL = "com.akashskypatel.reverbio/audio"
        private val INTENT_CHANNEL = "com.akashskypatel.reverbio/intent"
        private val TAG = "ReverbioMainActivity"
        private val NOTIFY_INTENT_METHOD_NAME = "onNewIntentUri"
    }

    private var intentMethodChannel: MethodChannel? = null
    private lateinit var intentUriProcessor: IntentUriProcessor
    private lateinit var audioDeviceUtils: AudioDeviceUtils

    @RequiresApi(VERSION_CODES.M)
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        /*
        // ─────────────────────────────
        // INTENT URI PROCESSOR CHANNEL
        // ─────────────────────────────
        intentUriProcessor.setOnNewUriCallback { uri ->
            intentMethodChannel?.invokeMethod(NOTIFY_INTENT_METHOD_NAME, uri)
        }
        intentUriProcessor = IntentUriProcessor(this)
        // Set up method channel
        intentMethodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL)
        intentMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialUri" -> {
                    val initialUri = intentUriProcessor.getCurrentUri()
                    result.success(initialUri)
                }

                "clearIntentCache" -> {
                    intentUriProcessor.clearCache()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
        */
        // ─────────────────────────────
        // AUDIO DEVICE CHANNEL
        // ─────────────────────────────
        audioDeviceUtils = AudioDeviceUtils(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getAudioOutputDevices" -> {
                        val deviceList = audioDeviceUtils.getAudioOutputDevices()
                        result.success(deviceList)
                    }

                    "setAudioOutputDevice" -> {
                        val deviceId = call.argument<Int?>("deviceId")
                        val success = audioDeviceUtils.setAudioOutputDevice(deviceId)
                        result.success(success)
                    }

                    "getCurrentAudioDevice" -> {
                        val currentDevice = audioDeviceUtils.getCurrentAudioDevice()
                        result.success(currentDevice)
                    }

                    "isAndroidAutoConnected" -> {
                        val isConnected = audioDeviceUtils.isAndroidAutoConnected()
                        result.success(isConnected)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "AUDIO_CHANNEL: ${call.method} failed", e)
                result.error("AUDIO_ERROR", e.localizedMessage, null)
            }
        }
        Log.d(TAG, "All native channels registered successfully.")
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
    }

    @RequiresApi(VERSION_CODES.M)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Aligns the Flutter view vertically with the window.
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false)

        if (VERSION.SDK_INT >= VERSION_CODES.S) {
            // Disable the Android splash screen fade out animation to avoid
            // a flicker before the similar frame is drawn in Flutter.
            splashScreen.setOnExitAnimationListener { splashScreenView -> splashScreenView.remove() }
        }
        if (audioDeviceUtils.isAndroidAutoConnected()) {
            // Initialize Android Auto-specific components
        }
        //handleInitialIntent()
    }
/*
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIncomingIntent(intent)
    }

    override fun onResume() {
        super.onResume()
    }

    private fun handleInitialIntent(intent: Intent?) {
        intent?.let { handleIncomingIntent(it) }
    }

    private fun handleIncomingIntent(intent: Intent) {
        val wasHandled = intentUriProcessor.handleIntent(intent)
        if (wasHandled) {
            Log.d("ReverbioMainActivity", "Intent handled successfully")
        }
    }
 */
}