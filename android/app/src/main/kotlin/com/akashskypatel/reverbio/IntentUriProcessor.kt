// IntentHandler.kt
package com.akashskypatel.reverbio

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class IntentUriProcessor(
    private val context: Context,
    private val cacheDirName: String = "IntentController"
) {
    companion object {
        private const val TAG = "ReverbioIntentHandler"
        const val SCHEME_CONTENT = "content"
        const val SCHEME_FILE = "file"
        const val SCHEME_HTTP = "http"
        const val SCHEME_HTTPS = "https"
    }

    private var currentUri: String? = null
    private var onNewUriCallback: ((String) -> Unit)? = null

    fun setOnNewUriCallback(callback: (String) -> Unit) {
        this.onNewUriCallback = callback
    }

    fun getCurrentUri(): String? = currentUri

    fun handleIntent(intent: Intent?): Boolean {
        if (intent == null) return false

        logIntentDetails(intent)

        val result = processIntentData(intent)
        logResult(result)

        return notifyIfNewUri(result)
    }

    fun clearCache() {
        try {
            val cacheDir = File(context.cacheDir, cacheDirName)
            if (cacheDir.exists()) {
                cacheDir.deleteRecursively()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing cache: ${e.message}", e)
        }
    }

    private fun logIntentDetails(intent: Intent) {
        Log.d(TAG, "Intent Action: ${intent.action}")
        Log.d(TAG, "Intent Data: ${intent.data}")
        Log.d(TAG, "Intent Scheme: ${intent.scheme}")
        Log.d(TAG, "Intent Type: ${intent.type}")
    }

    private fun processIntentData(intent: Intent): String? {
        return when (intent.data?.scheme?.lowercase()) {
            SCHEME_CONTENT -> handleContentScheme(intent)
            SCHEME_FILE, SCHEME_HTTP, SCHEME_HTTPS -> handleDirectSchemes(intent)
            else -> handleUnknownScheme(intent)
        }
    }

    private fun handleContentScheme(intent: Intent): String? {
        grantUriPermissions(intent)
        return copyContentToCache(intent.data)
    }

    private fun grantUriPermissions(intent: Intent) {
        val resolveInfos = context.packageManager.queryIntentActivities(
            intent,
            PackageManager.MATCH_DEFAULT_ONLY
        )

        for (resolveInfo in resolveInfos) {
            val packageName = resolveInfo.activityInfo.packageName
            context.grantUriPermission(
                packageName,
                intent.data,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }
    }

    private fun copyContentToCache(dataUri: Uri?): String? {
        if (dataUri == null) return null

        val targetDir = File(context.cacheDir, cacheDirName)
        targetDir.mkdirs()

        val targetFile = File(targetDir, dataUri.toString().md5())

        return if (shouldCopyFile(targetFile)) {
            performFileCopy(dataUri, targetFile)
        } else {
            getFileUri(targetFile)
        }
    }

    private fun shouldCopyFile(targetFile: File): Boolean {
        return targetFile.length() == 0L
    }

    private fun performFileCopy(dataUri: Uri, targetFile: File): String? {
        return try {
            prepareTargetDirectory(targetFile)
            copyUriContentToFile(dataUri, targetFile)
            getFileUri(targetFile)
        } catch (e: IOException) {
            Log.e(TAG, "Failed to copy content from URI: $dataUri", e)
            null
        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied for URI: $dataUri", e)
            null
        }
    }

    private fun prepareTargetDirectory(targetFile: File) {
        targetFile.parentFile?.mkdirs()
        if (targetFile.exists()) {
            targetFile.delete()
        }
    }
    }

    private fun copyUriContentToFile(dataUri: Uri, targetFile: File) {
        context.contentResolver.openInputStream(dataUri)?.use { inputStream ->
            FileOutputStream(targetFile).use { outputStream ->
                inputStream.copyTo(outputStream)
            }
        }
    }

    private fun getFileUri(targetFile: File): String {
        return "$SCHEME_FILE://${targetFile.absolutePath}"
    }

    private fun handleDirectSchemes(intent: Intent): String? {
        return intent.data?.toString()
    }

    private fun handleUnknownScheme(intent: Intent): String? {
        return null
    }

    private fun logResult(result: String?) {
        Log.d(TAG, "Processing result: $result")
        Log.d(TAG, "Current URI: $currentUri")
    }

    private fun notifyIfNewUri(result: String?): Boolean {
        if (result != null && result != currentUri) {
            currentUri = result
            onNewUriCallback?.invoke(result)
            Log.d(TAG, "New URI processed: $result")
            return true
        }
        return false
    }

    // Extension function for MD5 (if not already available)
    private fun String.md5(): String {
        val md = java.security.MessageDigest.getInstance("MD5")
        val digested = md.digest(toByteArray())
        return digested.joinToString("") {
            String.format("%02x", it)
        }
    }
}