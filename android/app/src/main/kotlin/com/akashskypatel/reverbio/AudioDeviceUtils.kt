package com.akashskypatel.reverbio

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import io.flutter.Log
import androidx.annotation.RequiresApi

class AudioDeviceUtils(private val activity: Activity) {
    private val TAG = "ReverbioAudioDeviceUtil"
    fun getAudioOutputDevices(): List<Map<String, Any>> {
        val uniqueDevices = mutableMapOf<String, Map<String, Any>>()
        val deviceCategories = mutableMapOf<String, String>()
        try {
            if (VERSION.SDK_INT >= VERSION_CODES.P) {
                val audioManager = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
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
    fun setAudioOutputDevice(deviceId: Int?): Boolean {
        val audioManager = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager

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
    fun getCurrentAudioDevice(): Map<String, Any>? {
        return try {
            val audioManager = activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager

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
                        "address" to (activeDevice.address),
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

    @RequiresApi(VERSION_CODES.M)
    fun isAndroidAutoConnected(): Boolean {
        val pm = activity.packageManager
        return pm.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE)
    }
}