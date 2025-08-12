package com.akashskypatel.reverbio
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.media.AudioManager
import android.media.AudioDeviceInfo
import androidx.annotation.NonNull
import androidx.core.view.WindowCompat
import androidx.annotation.RequiresApi
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import android.util.Log
import android.os.Process
import android.content.Context
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.content.pm.PackageManager
import android.provider.Settings

class MainActivity : AudioServiceActivity() {
  private val CHANNEL = "com.akashskypatel.reverbio/audio_device_channel"
  private val TAG = "AudioDeviceHandler"

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
      call, result ->
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
          else -> result.notImplemented()
        }
      } catch (e: Exception) {
        Log.e(TAG, "Error in method ${call.method}", e)
        result.error("AUDIO_ERROR", e.localizedMessage, null)
      }
    }
    Log.d(TAG, "Native channel registered")
  }

  private fun getAudioOutputDevices(): List<Map<String, Any>> {
    val uniqueDevices = mutableMapOf<String, Map<String, Any>>()
    val deviceCategories = mutableMapOf<String, String>()
    try {
      if (VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
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
    }  catch (e: Exception) {
      Log.e(TAG, "Error in method getAudioOutputDevices", e)
      throw e
    }
    return uniqueDevices.values.toList()
  }

  private fun categorizeDevice(device: AudioDeviceInfo): String {
    return when (device.type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> {
            when {
                device.productName?.toString()?.contains("Android Auto", ignoreCase = true) == true -> "Android Auto"
                device.productName?.toString()?.contains("Car", ignoreCase = true) == true -> "Car Audio"
                else -> "Bluetooth"
            }
        }
        AudioDeviceInfo.TYPE_USB_DEVICE -> {
            when {
                device.productName?.toString()?.contains("Auto", ignoreCase = true) == true -> "Android Auto"
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
          if (VERSION.SDK_INT >= VERSION_CODES.M) {
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

  private fun isAndroidAutoConnected(): Boolean {
    val pm = packageManager
    return pm.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE)
  }

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
