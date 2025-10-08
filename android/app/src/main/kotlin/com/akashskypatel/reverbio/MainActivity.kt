package com.akashskypatel.reverbio

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.os.Bundle
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val AUDIO_CHANNEL = "com.akashskypatel.reverbio/audio"
    private val MEDIA_PERMISSIONS_CHANNEL = "com.akashskypatel.reverbio/media_permissions"
    private val MEDIA_UTILS_CHANNEL = "com.akashskypatel.reverbio/media_utils"
    private val TAG = "ReverbioMainActivity"

    @RequiresApi(VERSION_CODES.M)
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ─────────────────────────────
        // AUDIO DEVICE CHANNEL
        // ─────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getAudioOutputDevices" -> {
                        val deviceList = getAudioOutputDevices()
                        result.success(deviceList)
                    }

                    "setAudioOutputDevice" -> {
                        val deviceId = call.argument<Int?>("deviceId")
                        val success = setAudioOutputDevice(deviceId)
                        result.success(success)
                    }

                    "getCurrentAudioDevice" -> {
                        val currentDevice = getCurrentAudioDevice()
                        result.success(currentDevice)
                    }

                    "canManageMedia" -> {
                        result.success(canManageMedia())
                    }

                    "requestManageMedia" -> {
                        requestManageMedia(result)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "AUDIO_CHANNEL: ${call.method} failed", e)
                result.error("AUDIO_ERROR", e.localizedMessage, null)
            }
        }
        // ─────────────────────────────
        // MEDIA PERMISSIONS CHANNEL
        // ─────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_PERMISSIONS_CHANNEL
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "canManageMedia" -> {
                        result.success(canManageMedia())
                    }

                    "requestManageMedia" -> {
                        requestManageMedia(result)
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "MEDIA_PERMISSIONS_CHANNEL: ${call.method} failed", e)
                result.error("MEDIA_PERMISSIONS_ERROR", e.localizedMessage, null)
            }
        }

        // ─────────────────────────────
        // MEDIA UTILITIES CHANNEL - UPDATED
        // ─────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_UTILS_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "pathToUri" -> {
                            val path = call.argument<String>("path")!!
                            val mime = call.argument<String?>("mimeType")
                            val uri = MediaUtils.pathToUri(this, path, mime)?.toString()
                            result.success(uri)
                        }

                        "createMediaFileFromBytes" -> {
                            val name = call.argument<String>("displayName")!!
                            val rel = call.argument<String>("relativePath")!!
                            val bytes = call.argument<ByteArray>("data")!!
                            val mime = call.argument<String?>("mimeType")
                            val uri =
                                MediaUtils.createMediaFileFromBytes(this, name, rel, bytes, mime)
                                    ?.toString()
                            result.success(uri)
                        }

                        "editMediaFile" -> {
                            val uriStr = call.argument<String>("uri")!!
                            val bytes = call.argument<ByteArray>("data")!!
                            val success = MediaUtils.editMediaFile(this, Uri.parse(uriStr), bytes)
                            result.success(success)
                        }

                        "deleteMediaFile" -> {
                            val id = call.argument<String>("identifier")!!
                            result.success(MediaUtils.deleteMediaFile(this, id))
                        }

                        "copyFileToMediaStore" -> {
                            val src = call.argument<String>("sourcePath")!!
                            val rel = call.argument<String>("relativePath")!!
                            val name = call.argument<String>("displayName")!!
                            val mime = call.argument<String?>("mimeType")
                            val uri = MediaUtils.copyFileToMediaStore(this, src, rel, name, mime)
                                ?.toString()
                            result.success(uri)
                        }

                        "copyUriToMediaStore" -> {
                            val srcUri = call.argument<String>("sourceUri")!!
                            val rel = call.argument<String>("relativePath")!!
                            val name = call.argument<String>("displayName")!!
                            val mime = call.argument<String?>("mimeType")
                            val uri = MediaUtils.copyUriToMediaStore(
                                this,
                                Uri.parse(srcUri),
                                rel,
                                name,
                                mime
                            )?.toString()
                            result.success(uri)
                        }

                        "readMediaFile" -> {
                            val pathOrUri = call.argument<String>("pathOrUri")!!
                            val mime = call.argument<String?>("mimeType")
                            val bytes = MediaUtils.readMediaFile(this, pathOrUri, mime)
                            result.success(bytes)
                        }

                        "copyToMediaStore" -> {
                            val source = call.argument<String>("source")!!
                            val destination = call.argument<String?>("destination")
                            val relativePath = call.argument<String?>("relativePath")
                            val displayName = call.argument<String?>("displayName")
                            val mime = call.argument<String?>("mimeType")
                            val uri = MediaUtils.copyToMediaStore(
                                this, source, destination, relativePath, displayName, mime
                            )?.toString()
                            result.success(uri)
                        }

                        "createMediaFile" -> {
                            val displayName = call.argument<String?>("displayName")
                            val destination = call.argument<String?>("destination")
                            val relativePath = call.argument<String?>("relativePath")
                            val dataSource = call.argument<Any>("dataSource")!!
                            val mime = call.argument<String?>("mimeType")
                            val uri = MediaUtils.createMediaFile(
                                this, displayName, destination, relativePath, dataSource, mime
                            )?.toString()
                            result.success(uri)
                        }

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "MEDIA_UTILS_CHANNEL: ${call.method} failed", e)
                    result.error("MEDIA_UTILS_ERROR", e.localizedMessage, null)
                }
            }
        Log.d(TAG, "All native channels registered successfully.")
    }

    /**
     * Checks if the app has been granted the special media management access.
     * Requires API level 31 (Android 12) or higher. On lower versions, this
     * level of access was not required in the same way.
     *
     * @return Boolean True if the app can manage media, false otherwise.
     */
    private fun canManageMedia(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaStore.canManageMedia(this)
        } else {
            // For devices below Android 12, assume true as the permission did not exist.
            // Your app's existing storage permissions (READ_EXTERNAL_STORAGE) would be checked instead.
            true
        }
    }

    /**
     * Opens the system settings screen where the user can grant your app
     * the special media management access.
     *
     * @param result The MethodChannel.Result object to return the outcome to Flutter.
     */
    private fun requestManageMedia(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_MANAGE_MEDIA)
            // Optional: Pre-select your app in the settings
            // intent.data = Uri.parse("package:${applicationContext.packageName}")
            startActivityForResult(intent, REQUEST_CODE_MANAGE_MEDIA)
            // The result of this action is handled in onActivityResult.
            // We inform Flutter that the request was launched successfully.
            result.success(null)
        } else {
            // On versions below Android 12, redirect to general app info settings
            // as the specific media management screen doesn't exist.
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = android.net.Uri.parse("package:${applicationContext.packageName}")
            startActivity(intent)
            result.success(null)
        }
    }

    // Handle the result coming back from the system settings screen
    @Deprecated("This method is deprecated in the Android API. Use the Activity Result API for modern alternatives.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_MANAGE_MEDIA) {
            // You can check the status again using canManageMedia() and inform Flutter via an EventChannel or a callback.
            // For simplicity, we are not handling the return here. The Flutter side can poll `canManageMedia` again later.
        }
    }

    companion object {
        private const val REQUEST_CODE_MANAGE_MEDIA = 2024 // Choose any unique number
    }

    private fun getAudioOutputDevices(): List<Map<String, Any>> {
        val uniqueDevices = mutableMapOf<String, Map<String, Any>>()
        val deviceCategories = mutableMapOf<String, String>()
        try {
            if (VERSION.SDK_INT >= VERSION_CODES.P) {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                for (device in devices) {
                    val category = categorizeDevice(device)
                    val deviceKey = "${device.productName}:${device.type}:${category}"
                    if (!uniqueDevices.containsKey(deviceKey)) {
                        uniqueDevices[deviceKey] = mapOf<String, Any>(
                            "id" to device.id,
                            "name" to (device.productName?.toString() ?: "Unknown"),
                            "type" to device.type,
                            "address" to (device.address ?: ""),
                            "category" to category
                        )
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in method getAudioOutputDevices", e)
            throw e
        }
        return uniqueDevices.values.toList()
    }

    @RequiresApi(VERSION_CODES.M)
    private fun categorizeDevice(device: AudioDeviceInfo): String {
        return when (device.type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> {
                when {
                    device.productName?.toString()
                        ?.contains("Android Auto", ignoreCase = true) == true -> "Android Auto"

                    device.productName?.toString()
                        ?.contains("Car", ignoreCase = true) == true -> "Car Audio"

                    else -> "Bluetooth"
                }
            }

            AudioDeviceInfo.TYPE_USB_DEVICE -> {
                when {
                    device.productName?.toString()
                        ?.contains("Auto", ignoreCase = true) == true -> "Android Auto"

                    else -> "USB Audio"
                }
            }

            AudioDeviceInfo.TYPE_REMOTE_SUBMIX -> "Android Auto"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired Headphones"
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired Headphones"
            AudioDeviceInfo.TYPE_USB_HEADSET -> "Wired Headphones"
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Phone Speaker"
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER_SAFE -> "Phone Speaker"
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Phone Earpiece"
            AudioDeviceInfo.TYPE_HDMI -> "HDMI"
            AudioDeviceInfo.TYPE_HDMI_ARC -> "HDMI"
            AudioDeviceInfo.TYPE_HDMI_EARC -> "HDMI"
            AudioDeviceInfo.TYPE_DOCK -> "Docking Station"
            AudioDeviceInfo.TYPE_DOCK_ANALOG -> "Docking Station"
            AudioDeviceInfo.TYPE_AUX_LINE -> "AUX"
            AudioDeviceInfo.TYPE_BLE_BROADCAST -> "Bluetooth"
            AudioDeviceInfo.TYPE_BLE_HEADSET -> "Bluetooth"
            AudioDeviceInfo.TYPE_BLE_SPEAKER -> "Bluetooth"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth"
            AudioDeviceInfo.TYPE_FM -> "Radio"
            AudioDeviceInfo.TYPE_FM_TUNER -> "Radio"
            AudioDeviceInfo.TYPE_HEARING_AID -> "Hearing Aid"
            else -> "Other"
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun setAudioOutputDevice(deviceId: Int?): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Handle automatic selection case
        if (deviceId == null) {
            return resetToAutomaticRouting(audioManager)
        }

        // Manual device selection (existing logic)
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val targetDevice = devices.firstOrNull { it.id == deviceId } ?: return false

        return when (targetDevice.type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> {
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                audioManager.isBluetoothScoOn = true
                audioManager.startBluetoothSco()
                true
            }

            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> {
                audioManager.mode = AudioManager.MODE_NORMAL
                audioManager.isSpeakerphoneOn = false
                true
            }

            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> {
                audioManager.mode = AudioManager.MODE_NORMAL
                audioManager.isSpeakerphoneOn = true
                true
            }

            AudioDeviceInfo.TYPE_USB_DEVICE -> {
                audioManager.mode = AudioManager.MODE_NORMAL
                audioManager.isSpeakerphoneOn = false
                true
            }

            else -> false
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun resetToAutomaticRouting(audioManager: AudioManager): Boolean {
        return try {
            // Reset all manual routing settings
            audioManager.mode = AudioManager.MODE_NORMAL
            audioManager.isSpeakerphoneOn = false

            // Stop any forced audio routing
            if (audioManager.isBluetoothScoOn) {
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
            }

            true
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting to automatic routing", e)
            false
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun getCurrentAudioDevice(): Map<String, Any>? {
        return try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            // For API 23+
            if (VERSION.SDK_INT >= VERSION_CODES.P) {
                val routing = audioManager.getRouting(AudioManager.MODE_NORMAL)
                val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

                devices.firstOrNull { device ->
                    // Check if this device matches the current routing
                    (device.type and routing) != 0
                }?.let { activeDevice ->
                    mapOf<String, Any>(
                        "id" to activeDevice.id,
                        "name" to (activeDevice.productName?.toString() ?: "Unknown"),
                        "type" to activeDevice.type,
                        "address" to (activeDevice.address ?: ""),
                        "category" to categorizeDevice(activeDevice)
                    )
                }
            } else {
                // Fallback for older APIs
                mapOf<String, Any>(
                    "type" to when {
                        audioManager.isBluetoothA2dpOn -> AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
                        audioManager.isWiredHeadsetOn -> AudioDeviceInfo.TYPE_WIRED_HEADSET
                        else -> AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                    },
                    "name" to when {
                        audioManager.isBluetoothA2dpOn -> "Bluetooth"
                        audioManager.isWiredHeadsetOn -> "Wired Headphones"
                        else -> "Phone Speaker"
                    },
                    "category" to when {
                        audioManager.isBluetoothA2dpOn -> "Bluetooth"
                        audioManager.isWiredHeadsetOn -> "Wired Headphones"
                        else -> "Phone Speaker"
                    }
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting current audio device", e)
            null
        }
    }

    @RequiresApi(VERSION_CODES.ECLAIR)
    private fun isAndroidAutoConnected(): Boolean {
        val pm = packageManager
        return pm.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE)
    }

    @RequiresApi(VERSION_CODES.ECLAIR)
    override fun onCreate(savedInstanceState: Bundle?) {
        // Aligns the Flutter view vertically with the window.
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Disable the Android splash screen fade out animation to avoid
            // a flicker before the similar frame is drawn in Flutter.
            splashScreen.setOnExitAnimationListener { splashScreenView -> splashScreenView.remove() }
        }
        if (isAndroidAutoConnected()) {
            // Initialize Android Auto-specific components
        }
        super.onCreate(savedInstanceState)
    }
}