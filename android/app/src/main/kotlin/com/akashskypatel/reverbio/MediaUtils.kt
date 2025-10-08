package com.akashskypatel.reverbio

import android.annotation.SuppressLint
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.Log
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.net.URLConnection

@SuppressLint("NewApi")
object MediaUtils {
    private const val TAG = "MediaUtils"
    /**
     * Convert a file or directory path to a MediaStore or FileProvider compatible Uri.
     * Optional [mimeType] can improve accuracy when known.
     */
    fun pathToUri(context: Context, path: String, mimeType: String? = null): Uri? {
        val file = File(path)
        if (!file.exists()) return null

        val resolvedMime = mimeType ?: getMimeTypeFromFile(context, file)
        val collection = getCollectionForMimeType(resolvedMime)

        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection = "${MediaStore.MediaColumns.DATA}=?"
        val selectionArgs = arrayOf(file.absolutePath)

        context.contentResolver.query(collection, projection, selection, selectionArgs, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id =
                        cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID))
                    return Uri.withAppendedPath(collection, id.toString())
                }
            }

        // Fallback to FileProvider
        return try {
            FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting uri: ${e.message}", e)
            null
        }
    }

    /**
     * Create and write data directly into a MediaStore file.
     * Auto-detects or accepts an optional [mimeType].
     */
    fun createMediaFileFromBytes(
        context: Context,
        displayName: String,
        relativePath: String,
        data: ByteArray,
        mimeType: String? = null
    ): Uri? {
        val resolvedMime = mimeType ?: detectMimeTypeFromBytes(data) ?: "application/octet-stream"
        return try {
            createMediaFile(
                context,
                displayName = displayName,
                mimeType = resolvedMime,
                relativePath = relativePath,
                dataSource = data
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error creating media file: ${e.message}", e)
            null
        }
    }

    /**
     * Edit (overwrite) an existing media file by Uri.
     */
    fun editMediaFile(context: Context, uri: Uri, data: ByteArray): Boolean {
        return runCatching {
            context.contentResolver.openOutputStream(uri, "w")?.use { it.write(data) }
                ?: throw IOException("Failed to open output stream for URI: $uri")
            true
        }.getOrElse { exception ->
            when (exception) {
                is IOException, is SecurityException -> {
                    Log.e(TAG, "Failed to overwrite media file: $uri", exception)
                }
                else -> throw exception // Re-throw unexpected exceptions
            }
            false
        }
    }

    /**
     * Delete a media file using its Uri or file path.
     */
    fun deleteMediaFile(context: Context, identifier: String): Boolean {
        val uri = if (identifier.startsWith("content://")) Uri.parse(identifier)
        else pathToUri(context, identifier)

        uri?.let {
            return try {
                context.contentResolver.delete(it, null, null) > 0
            } catch (e: Exception) {
                Log.e(TAG, "Error deleting media file: ${e.message}", e)
                false
            }
        }
        return false
    }

    /**
     * Copy a local file to MediaStore. Optionally supply [mimeType].
     */
    fun copyFileToMediaStore(
        context: Context,
        sourcePath: String,
        relativePath: String,
        displayName: String,
        mimeType: String? = null
    ): Uri? {
        val srcFile = File(sourcePath)
        if (!srcFile.exists()) return null

        val resolvedMime =
            mimeType ?: getMimeTypeFromFile(context, srcFile) ?: "application/octet-stream"
        return try {
            createMediaFile(
                context,
                displayName = displayName,
                mimeType = resolvedMime,
                relativePath = relativePath,
                dataSource = srcFile.readBytes()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error copying media file: ${e.message}", e)
            null
        }
    }

    /**
     * Copy from a Uri (e.g. gallery picker result) to MediaStore.
     * Optionally supply [mimeType].
     */
    fun copyUriToMediaStore(
        context: Context,
        sourceUri: Uri,
        relativePath: String,
        displayName: String,
        mimeType: String? = null
    ): Uri? {
        val resolvedMime = mimeType
            ?: context.contentResolver.getType(sourceUri)
            ?: "application/octet-stream"
        val data = context.contentResolver.openInputStream(sourceUri)?.use { it.readBytes() }
            ?: return null
        return try {
            createMediaFile(
                context,
                displayName = displayName,
                mimeType = resolvedMime,
                relativePath = relativePath,
                dataSource = data
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error copying media file: ${e.message}", e)
            null
        }
    }

    /**
     * Read a media file and return its bytes.
     * Accepts either a file path or a content Uri.
     * Optional mimeType parameter can be used for validation.
     */
    fun readMediaFile(
        context: Context,
        pathOrUri: String,
        mimeType: String? = null
    ): ByteArray? {
        val uri: Uri? = if (pathOrUri.startsWith("content://")) {
            Uri.parse(pathOrUri)
        } else {
            pathToUri(context, pathOrUri, mimeType)
        }

        if (uri == null) return null

        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                input.readBytes()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading media file: ${e.message}", e)
            null
        }
    }

    /**
     * Enhanced copy function that supports multiple source and destination types
     */
    fun copyToMediaStore(
        context: Context,
        source: String, // Can be file path OR content URI
        destination: String? = null, // Optional: can be content URI, file path, or relative path
        relativePath: String? = null, // Optional: if destination not provided
        displayName: String? = null, // Optional: if null, will use source file name
        mimeType: String? = null
    ): Uri? {
        return try {
            // Handle destination based on its type
            when {
                destination == null -> {
                    // Use auto-detected relative path
                    copyToAutoDestination(context, source, relativePath, displayName, mimeType)
                }

                destination.startsWith("content://") -> {
                    // Destination is direct content URI - overwrite existing file
                    copyToExistingUri(context, source, destination, mimeType)
                }

                destination.startsWith("/") -> {
                    // Destination is file path - copy to file system
                    copyToFileSystem(context, source, destination, mimeType)
                }

                else -> {
                    // Destination is relative path - create new MediaStore entry
                    copyToRelativePath(context, source, destination, displayName, mimeType)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error copying media file: ${e.message}", e)
            null
        }
    }

    /**
     * Enhanced create media file function with multiple destination options
     */
    fun createMediaFile(
        context: Context,
        displayName: String? = null,
        destination: String? = null, // Can be content URI, file path, or relative path
        relativePath: String? = null, // Optional: for backward compatibility
        dataSource: Any, // Can be ByteArray, file path String, or content URI String
        mimeType: String? = null
    ): Uri? {
        return try {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            }
            val collection = getCollectionForMimeType(mimeType)
            resolver.insert(collection, values)
            // Handle destination based on its type
            val finalDestination = destination ?: relativePath

            when {
                finalDestination == null -> {
                    // Auto-detect destination from dataSource
                    createToAutoDestination(context, displayName, dataSource, mimeType)
                }

                finalDestination.startsWith("content://") -> {
                    // Destination is direct content URI - overwrite existing
                    createToExistingUri(context, finalDestination, dataSource, mimeType)
                }

                finalDestination.startsWith("/") -> {
                    // Destination is file path - create file
                    createToFileSystem(context, displayName, finalDestination, dataSource, mimeType)
                }

                else -> {
                    // Destination is relative path - create in MediaStore
                    createToRelativePath(
                        context,
                        displayName,
                        finalDestination,
                        dataSource,
                        mimeType
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error creating media file: ${e.message}", e)
            null
        }
    }

    // ────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ────────────────────────────────────────────────

    private fun getMimeTypeFromFile(context: Context, file: File): String? {
        val uri = Uri.fromFile(file)
        val type = context.contentResolver.getType(uri)
        if (!type.isNullOrEmpty()) return type
        val ext = file.extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
    }

    private fun detectMimeTypeFromBytes(data: ByteArray): String? {
        return try {
            val input = data.inputStream()
            input.mark(0)
            val mime = URLConnection.guessContentTypeFromStream(input)
            input.reset()
            mime
        } catch (e: Exception) {
            null
        }
    }

    private fun getCollectionForMimeType(mimeType: String?): Uri {
        // On Android 10+ (API 29+), MediaStore.Downloads is the preferred location
        // for non-media files. For older versions, we must use the general Files collection.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return when {
                mimeType?.startsWith("image/") == true -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                mimeType?.startsWith("video/") == true -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                mimeType?.startsWith("audio/") == true -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                else -> MediaStore.Downloads.EXTERNAL_CONTENT_URI // For documents, etc.
            }
        } else {
            return when {
                mimeType?.startsWith("image/") == true -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                mimeType?.startsWith("video/") == true -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                mimeType?.startsWith("audio/") == true -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                else -> MediaStore.Files.getContentUri("external") // Fallback for older APIs
            }
        }
    }

    // ────────────────────────────────────────────────
    // DESTINATION HANDLING HELPERS
    // ────────────────────────────────────────────────

    /**
     * Maps file system directory paths to MediaStore relative paths
     */
    private fun mapFileSystemPathToMediaStoreRelative(fileSystemPath: String): String {
        val normalizedPath = fileSystemPath.lowercase().trim()

        return when {
            // Music directories
            normalizedPath.contains("/music/") ||
                    normalizedPath.endsWith("/music") -> "Music/"

            normalizedPath.contains("/downloads/") ||
                    normalizedPath.endsWith("/download") ||
                    normalizedPath.endsWith("/downloads") -> "Downloads/"

            // Picture directories
            normalizedPath.contains("/pictures/") ||
                    normalizedPath.endsWith("/pictures") ||
                    normalizedPath.contains("/dcim/") ||
                    normalizedPath.endsWith("/dcim") -> "Pictures/"

            // Video directories
            normalizedPath.contains("/movies/") ||
                    normalizedPath.endsWith("/movies") ||
                    normalizedPath.contains("/video/") ||
                    normalizedPath.endsWith("/video") -> "Movies/"

            // Document directories
            normalizedPath.contains("/documents/") ||
                    normalizedPath.endsWith("/documents") ||
                    normalizedPath.contains("/document/") -> "Documents/"

            // Audio books
            normalizedPath.contains("/audiobooks/") ||
                    normalizedPath.endsWith("/audiobooks") -> "Audiobooks/"

            // Podcasts
            normalizedPath.contains("/podcasts/") ||
                    normalizedPath.endsWith("/podcasts") -> "Podcasts/"

            // Notifications
            normalizedPath.contains("/notifications/") ||
                    normalizedPath.endsWith("/notifications") -> "Notifications/"

            // Ringtones
            normalizedPath.contains("/ringtones/") ||
                    normalizedPath.endsWith("/ringtones") -> "Ringtones/"

            // Alarms
            normalizedPath.contains("/alarms/") ||
                    normalizedPath.endsWith("/alarms") -> "Alarms/"

            // Default case - extract the last directory name or use "Files/"
            else -> {
                val segments = fileSystemPath.trim('/').split('/')
                if (segments.isNotEmpty()) {
                    val lastSegment = segments.last()
                    if (lastSegment.isNotBlank() && lastSegment != "0" && lastSegment != "emulated") {
                        "$lastSegment/"
                    } else {
                        "Files/"
                    }
                } else {
                    "Files/"
                }
            }
        }
    }

    /**
     * Extracts subdirectory structure from file system path for more precise mapping
     */
    private fun extractSubdirectoryStructure(fileSystemPath: String, sourceFile: String): String {
        val file = File(sourceFile)
        val parentPath = file.parent ?: return ""

        // Remove the base storage path to get relative structure
        val basePaths = arrayOf(
            "/storage/emulated/0/",
            "/storage/0000-0000/",
            "/sdcard/",
            "/external_storage/"
        )

        var relativePath = parentPath
        for (basePath in basePaths) {
            if (parentPath.startsWith(basePath)) {
                relativePath = parentPath.substring(basePath.length)
                break
            }
        }

        // Map common directories
        return when {
            relativePath.startsWith("Music/") -> relativePath.replace("Music/", "")
            relativePath.startsWith("Downloads/") -> relativePath.replace("Downloads/", "")
            relativePath.startsWith("Pictures/") || relativePath.startsWith("DCIM/") ->
                relativePath.replace("Pictures/", "").replace("DCIM/", "")

            relativePath.startsWith("Movies/") || relativePath.startsWith("Videos/") ->
                relativePath.replace("Movies/", "").replace("Videos/", "")

            relativePath.startsWith("Documents/") -> relativePath.replace("Documents/", "")
            else -> relativePath
        }.trim('/') + "/"
    }

    /**
     * Extracts display name from source path/URI
     */
    private fun extractDisplayNameFromSource(context: Context, source: String): String {
        return when {
            source.startsWith("content://") -> {
                val uri = Uri.parse(source)
                context.contentResolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME),
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1) {
                            return cursor.getString(nameIndex)
                        }
                    }
                }
                // Fallback if the query fails
                "file_${System.currentTimeMillis()}"
            }

            else -> {
                File(source).name.takeIf { it.isNotBlank() } ?: "file_${System.currentTimeMillis()}"
            }
        }
    }

    /**
     * Extracts and converts relative path from source file path
     */
    private fun extractRelativePathFromSource(source: String): String {
        if (source.startsWith("content://")) {
            // For content URIs, use a default location
            return "Files/"
        }

        val sourceFile = File(source)
        val parentPath = sourceFile.parent ?: return "Files/"

        // Get base MediaStore directory
        val baseDir = mapFileSystemPathToMediaStoreRelative(parentPath)

        // Extract subdirectory structure for more precise organization
        val subdirs = extractSubdirectoryStructure(parentPath, source)

        return baseDir + subdirs
    }

    // ────────────────────────────────────────────────
    // COPY DESTINATION IMPLEMENTATIONS
    // ────────────────────────────────────────────────

    private fun copyToAutoDestination(
        context: Context,
        source: String,
        relativePath: String?,
        displayName: String?,
        mimeType: String?
    ): Uri? {
        val finalDisplayName = displayName ?: extractDisplayNameFromSource(context, source)
        val finalRelativePath = relativePath ?: extractRelativePathFromSource(source)

        return if (source.startsWith("content://")) {
            val sourceUri = Uri.parse(source)
            copyUriToMediaStore(context, sourceUri, finalRelativePath, finalDisplayName, mimeType)
        } else {
            copyFileToMediaStore(context, source, finalRelativePath, finalDisplayName, mimeType)
        }
    }

    private fun copyToExistingUri(
        context: Context,
        source: String,
        destinationUri: String,
        mimeType: String?
    ): Uri? {
        return try {
            val destUri = Uri.parse(destinationUri)
            val data = when {
                source.startsWith("content://") -> {
                    // Read from content URI
                    context.contentResolver.openInputStream(Uri.parse(source))
                        ?.use { it.readBytes() }
                }

                else -> {
                    // Read from file path
                    File(source).readBytes()
                }
            }

            data?.let {
                val success = editMediaFile(context, destUri, it)
                if (success) destUri else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error copying media file: ${e.message}", e)
            null
        }
    }

    private fun copyToFileSystem(
        context: Context,
        source: String,
        destinationPath: String,
        mimeType: String?
    ): Uri? {
        return try {
            val destFile = File(destinationPath)
            destFile.parentFile?.mkdirs()

            when {
                source.startsWith("content://") -> {
                    // Copy from content URI to file system
                    context.contentResolver.openInputStream(Uri.parse(source))?.use { input ->
                        destFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                }

                else -> {
                    // Copy from file path to file path
                    File(source).copyTo(destFile, overwrite = true)
                }
            }

            // Return file path as URI
            Uri.fromFile(destFile)
        } catch (e: Exception) {
            Log.e(TAG, "Error copying media file: ${e.message}", e)
            null
        }
    }

    private fun copyToRelativePath(
        context: Context,
        source: String,
        relativePath: String,
        displayName: String?,
        mimeType: String?
    ): Uri? {
        val finalDisplayName = displayName ?: extractDisplayNameFromSource(context, source)

        return if (source.startsWith("content://")) {
            val sourceUri = Uri.parse(source)
            copyUriToMediaStore(context, sourceUri, relativePath, finalDisplayName, mimeType)
        } else {
            copyFileToMediaStore(context, source, relativePath, finalDisplayName, mimeType)
        }
    }

    // ────────────────────────────────────────────────
    // CREATE DESTINATION IMPLEMENTATIONS
    // ────────────────────────────────────────────────

    private fun createToAutoDestination(
        context: Context,
        displayName: String?,
        dataSource: Any,
        mimeType: String?
    ): Uri? {
        val finalDisplayName = when (dataSource) {
            is String -> displayName ?: extractDisplayNameFromSource(context, dataSource)
            else -> displayName ?: "file_${System.currentTimeMillis()}"
        }

        val finalRelativePath = when (dataSource) {
            is String -> extractRelativePathFromSource(dataSource)
            else -> "Files/"
        }

        return when (dataSource) {
            is ByteArray -> createMediaFileFromBytes(
                context,
                finalDisplayName,
                finalRelativePath,
                dataSource,
                mimeType
            )

            is String -> {
                if (dataSource.startsWith("content://")) {
                    copyUriToMediaStore(
                        context,
                        Uri.parse(dataSource),
                        finalRelativePath,
                        finalDisplayName,
                        mimeType
                    )
                } else {
                    copyFileToMediaStore(
                        context,
                        dataSource,
                        finalRelativePath,
                        finalDisplayName,
                        mimeType
                    )
                }
            }

            else -> null
        }
    }

    private fun createToExistingUri(
        context: Context,
        destinationUri: String,
        dataSource: Any,
        mimeType: String?
    ): Uri? {
        return try {
            val destUri = Uri.parse(destinationUri)
            val data = when (dataSource) {
                is ByteArray -> dataSource
                is String -> {
                    if (dataSource.startsWith("content://")) {
                        context.contentResolver.openInputStream(Uri.parse(dataSource))
                            ?.use { it.readBytes() }
                    } else {
                        File(dataSource).readBytes()
                    }
                }

                else -> null
            }

            data?.let {
                val success = editMediaFile(context, destUri, it)
                if (success) destUri else null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error creating media file: ${e.message}", e)
            null
        }
    }

    private fun createToFileSystem(
        context: Context,
        displayName: String?,
        destinationPath: String,
        dataSource: Any,
        mimeType: String?
    ): Uri? {
        return try {
            val destFile = File(destinationPath)
            destFile.parentFile?.mkdirs()

            when (dataSource) {
                is ByteArray -> {
                    destFile.writeBytes(dataSource)
                }

                is String -> {
                    if (dataSource.startsWith("content://")) {
                        context.contentResolver.openInputStream(Uri.parse(dataSource))
                            ?.use { input ->
                                destFile.outputStream().use { output ->
                                    input.copyTo(output)
                                }
                            }
                    } else {
                        File(dataSource).copyTo(destFile, overwrite = true)
                    }
                }
            }

            Uri.fromFile(destFile)
        } catch (e: Exception) {
            Log.e(TAG, "Error creating media file: ${e.message}", e)
            null
        }
    }

    private fun createToRelativePath(
        context: Context,
        displayName: String?,
        relativePath: String,
        dataSource: Any,
        mimeType: String?
    ): Uri? {
        val finalDisplayName = displayName ?: when (dataSource) {
            is String -> extractDisplayNameFromSource(context, dataSource)
            else -> "file_${System.currentTimeMillis()}"
        }

        return when (dataSource) {
            is ByteArray -> createMediaFileFromBytes(
                context,
                finalDisplayName,
                relativePath,
                dataSource,
                mimeType
            )

            is String -> {
                if (dataSource.startsWith("content://")) {
                    copyUriToMediaStore(
                        context,
                        Uri.parse(dataSource),
                        relativePath,
                        finalDisplayName,
                        mimeType
                    )
                } else {
                    copyFileToMediaStore(
                        context,
                        dataSource,
                        relativePath,
                        finalDisplayName,
                        mimeType
                    )
                }
            }

            else -> null
        }
    }
}