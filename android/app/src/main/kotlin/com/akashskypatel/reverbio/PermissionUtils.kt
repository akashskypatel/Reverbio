package com.akashskypatel.reverbio

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel

class PermissionUtils(private val activity: Activity) {
    private val application: Application = activity.application
    // This would typically be inside an Activity or Fragment, so these methods would need access to an Activity context.
    // For this example, assuming 'context' is an Activity context for starting activities.
    private val TAG = "ReverbioPermissionUtils"
    companion object {
        private const val REQUEST_CODE_MANAGE_MEDIA = 2024 // Choose any unique number
    }
    /**
     * Checks if the app has been granted the special media management access.
     * Requires API level 31 (Android 12) or higher. On lower versions, this
     * level of access was not required in the same way.
     *
     * @return Boolean True if the app can manage media, false otherwise.
     */
    fun canManageMedia(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaStore.canManageMedia(application.applicationContext)
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
    fun requestManageMedia(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_MANAGE_MEDIA)
            // Optional: Pre-select your app in the settings
            // intent.data = Uri.parse("package:${applicationContext.packageName}")
            activity.startActivityForResult(intent, REQUEST_CODE_MANAGE_MEDIA)
            // The result of this action is handled in onActivityResult.
            // We inform Flutter that the request was launched successfully.
            result.success(null)
        } else {
            // On versions below Android 12, redirect to general app info settings
            // as the specific media management screen doesn't exist.
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = android.net.Uri.parse("package:${application.applicationContext.packageName}")
            application.startActivity(intent)
            result.success(null)
        }
    }
}