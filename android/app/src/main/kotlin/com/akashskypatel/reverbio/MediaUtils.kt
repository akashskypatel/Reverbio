package com.akashskypatel.reverbio

import android.app.Activity
import android.app.PendingIntent
import android.app.RecoverableSecurityException
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.annotation.RequiresApi
import androidx.core.content.FileProvider
import io.flutter.Log
import java.io.File
import java.io.IOException
import java.net.URLConnection

@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
class MediaUtils(private val activity: Activity) {
    companion object {
        private val TAG = "ReverbioMediaUtils"
        private val CONTENT_URI_PREFIX = "content://"
        private val FILE_PROVIDER_AUTHORITY = "com.akashskypatel.reverbio.fileprovider"
        private val DIRECTORY_COLLECTION_21 = mapOf(
            Environment.DIRECTORY_MUSIC to MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_PODCASTS to MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_RINGTONES to MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_ALARMS to MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_NOTIFICATIONS to MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_PICTURES to MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_MOVIES to MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_DCIM to MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
        )

        @RequiresApi(Build.VERSION_CODES.S)
        private val DIRECTORY_COLLECTION_31 = mapOf(
            Environment.DIRECTORY_DOCUMENTS to MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL),
            Environment.DIRECTORY_DOWNLOADS to MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_AUDIOBOOKS to MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_SCREENSHOTS to MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            Environment.DIRECTORY_RECORDINGS to MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        )
        private val DIRECTORY_COLLECTION
            get(): Map<String, Uri> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    return DIRECTORY_COLLECTION_21 + DIRECTORY_COLLECTION_31
                } else {
                    return DIRECTORY_COLLECTION_21
                }
            }

        // Media directory mappings
        private val MEDIA_DIRECTORIES: Map<String, String> by lazy {
            val baseDirs = mutableMapOf(
                Environment.DIRECTORY_MUSIC to "Music/",
                Environment.DIRECTORY_PODCASTS to "Podcasts/",
                Environment.DIRECTORY_RINGTONES to "Ringtones/",
                Environment.DIRECTORY_ALARMS to "Alarms/",
                Environment.DIRECTORY_NOTIFICATIONS to "Notifications/",
                Environment.DIRECTORY_PICTURES to "Pictures/",
                Environment.DIRECTORY_MOVIES to "Movies/",
                Environment.DIRECTORY_DOWNLOADS to "Download/",
                Environment.DIRECTORY_DCIM to "DCIM/",
                Environment.DIRECTORY_DOCUMENTS to "Documents/"
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                baseDirs[Environment.DIRECTORY_AUDIOBOOKS] = "Audiobooks/"
                baseDirs[Environment.DIRECTORY_SCREENSHOTS] = "Pictures/Screenshots/"
                baseDirs[Environment.DIRECTORY_RECORDINGS] = "Recordings/"
            }
            baseDirs
        }
    }

    public val DELETE_REQUEST_CODE = "delete".hashCode()
    public val WRITE_REQUEST_CODE = "write".hashCode()
    public val DELETE_REQUEST_NOTIFY = "notifyDeleteComplete"
    public val WRITE_REQUEST_NOTIFY = "notifyCreateComplete"

    // Permission operation queue
    private val pendingWriteOperations = mutableListOf<WriteOperation>()
    private val pendingDeleteOperations = mutableListOf<DeleteOperation>()

    data class MediaDetails(
        val displayName: String,
        val mimeType: String,
        val relativePath: String
    )

    data class WriteOperation(
        val destinationUri: Uri,
        val data: ByteArray? = null,
        val sourceUri: Uri? = null,
        val onSuccess: ((Uri?) -> Unit)? = null,
        val onFail: ((Exception) -> Unit)? = null
    ) {
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (javaClass != other?.javaClass) return false

            other as WriteOperation

            if (destinationUri != other.destinationUri) return false
            if (!data.contentEquals(other.data)) return false
            if (sourceUri != other.sourceUri) return false
            if (onSuccess != other.onSuccess) return false
            if (onFail != other.onFail) return false

            return true
        }

        override fun hashCode(): Int {
            var result = destinationUri.hashCode()
            result = 31 * result + (data?.contentHashCode() ?: 0)
            result = 31 * result + (sourceUri?.hashCode() ?: 0)
            result = 31 * result + (onSuccess?.hashCode() ?: 0)
            result = 31 * result + (onFail?.hashCode() ?: 0)
            return result
        }
    }

    data class DeleteOperation(
        val uri: Uri,
        val onSuccess: (() -> Unit)? = null,
        val onFail: ((Exception) -> Unit)? = null
    )

    // ─────────────────────────────
    // PUBLIC API METHODS
    // ─────────────────────────────
    fun isInitialized(): Boolean {
        return true
    }

    /**
     * Convert a file or directory path to a MediaStore or FileProvider compatible Uri.
     * Optional [mimeType] can improve accuracy when known.
     */
    fun pathToUri(context: Context, path: String, mimeType: String? = null): Uri? {
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        if (path.lowercase().startsWith(CONTENT_URI_PREFIX.lowercase())) {
            context.contentResolver.query(Uri.parse(path), projection, null, null, null)
                ?.use { cursor ->
                    cursor.moveToFirst()
                    cursor.close()
                    return Uri.parse(path)
                }
        } else {
            val file = File(path)
            if (!file.exists()) return null

            val resolvedMime = mimeType ?: getMimeTypeFromFile(context, file)
            val collection = getCollectionForMimeType(resolvedMime)
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
                FileProvider.getUriForFile(
                    context,
                    FILE_PROVIDER_AUTHORITY,
                    file
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error getting uri: ${e.message}", e)
                null
            }
        }
        return null
    }

    /**
     * Convert a MediaStore URI to a file system path.
     * Returns the file path if found, null otherwise.
     */
    fun uriToPath(context: Context, uri: Uri): String? {
        return try {
            // For file provider URIs, extract path directly
            if (uri.scheme == "file") {
                return uri.path
            } else if (uri.authority?.lowercase() == FILE_PROVIDER_AUTHORITY) {
                val pathSegments = uri.pathSegments
                return if (pathSegments.isNotEmpty()) {
                    when (pathSegments[0]) {
                        "internal_files" -> {
                            val internalPath = pathSegments.drop(1).joinToString("/")
                            File(context.filesDir, internalPath).absolutePath
                        }

                        "external_files" -> {
                            val externalPath = pathSegments.drop(1).joinToString("/")
                            context.getExternalFilesDir(null)?.let {
                                File(it, externalPath).absolutePath
                            }
                        }

                        "cache" -> {
                            val cachePath = pathSegments.drop(1).joinToString("/")
                            File(context.cacheDir, cachePath).absolutePath
                        }

                        "external_cache" -> {
                            val externalCachePath = pathSegments.drop(1).joinToString("/")
                            context.externalCacheDir?.let {
                                File(it, externalCachePath).absolutePath
                            }
                        }

                        else -> {
                            // Generic fallback for other path types
                            val genericPath = pathSegments.joinToString("/")
                            File(context.filesDir, genericPath).absolutePath
                        }
                    }
                } else
                    null
            } else if (uri.authority?.lowercase() == "media") {
                // For MediaStore URIs, query the DATA column
                val projection = arrayOf(MediaStore.MediaColumns.DATA)
                context.contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val columnIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
                        return cursor.getString(columnIndex)
                    }
                    return null
                }
            } else {
                // Fallback for DocumentsProvider URIs
                if (uri.authority == "com.android.externalStorage.documents") {
                    parseDocumentUri(uri)
                }
            }
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error converting URI to path: ${e.message}", e)
            null
        }
    }

    /**
     * Edit (overwrite) an existing media file by Uri.
     * Uses MediaStore.createWriteRequest for Android 11+ when needed.
     */
    fun editMediaFile(
        context: Context,
        pathOrUri: String,
        data: ByteArray,
    ): Boolean {
        return runCatching {
            val uri = resolveUriFromString(context, pathOrUri)
            return uri?.let {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        createWriteRequest(context, uri, data = data)
                        true
                    } else {
                        // Immediate execution for older versions
                        context.contentResolver.openOutputStream(uri, "w")?.use {
                            it.write(data)
                        } ?: throw IOException("Failed to open output stream")
                        true
                    }
                } catch (e: Exception) {
                    File(pathOrUri).writeBytes(data)
                    true
                }
            } == true
        }.getOrElse { e ->
            Log.e(TAG, "Failed to edit media file at $pathOrUri: ${e.message}", e)
            false
        }
    }

    /**
     * Read a media file and returns its bytes.
     * Uses MediaStore.openFileDescriptor for better file access.
     */
    fun readMediaFile(
        context: Context,
        pathOrUri: String,
    ): ByteArray? {
        runCatching {
            val uri = resolveUriFromString(context, pathOrUri)
            return uri?.let {
                return try {
                    context.contentResolver.openInputStream(uri)?.use { input ->
                        input.readBytes()
                    }
                } catch (e: Exception) {
                    File(pathOrUri).readBytes()
                }
            }
        }.getOrElse { e ->
            Log.e(TAG, "Error reading media file at $pathOrUri: ${e.message}", e)
            null
        }
        return null
    }

    /**
     * Delete a media file using its Uri or file path.
     * Uses MediaStore.createDeleteRequest for Android 11+ when needed.
     */
    fun deleteMediaFile(context: Context, identifier: String): Boolean {
        val uri = if (identifier.startsWith(CONTENT_URI_PREFIX)) Uri.parse(identifier)
        else pathToUri(context, identifier)
        return uri?.let {
            runCatching {
                createDeleteRequest(context, it)
                true // Operation queued, will execute later
            }.getOrDefault(false)
        } ?: false
    }

    fun createMediaFileAtRelative(
        context: Context,
        displayName: String,
        relativePath: String? = null,
        data: ByteArray,
        mimeType: String? = null
    ): Uri? {
        return runCatching {
            val mime = mimeType ?: getMimeTypeFromBytes(data)
            val relative = relativePath?.let { validateRelativePath(it) }
            return if (relative != null && mime != null) {
                val uri = findOrCreateMediaStoreEntry(
                    context,
                    null,
                    MediaDetails(displayName, mime, relative)
                )
                if (uri != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        createWriteRequest(context, uri, data = data)
                        uri
                    } else {
                        context.contentResolver.openOutputStream(uri, "w")?.use {
                            it.write(data)
                        }
                        uri
                    }
                } else {
                    Log.e(TAG, "Failed to create media entry at $relative: $displayName, $mimeType")
                    null
                }
            } else {
                Log.e(
                    TAG,
                    "Failed to create media file: Invalid relativePath or mimeType: $relativePath, $mimeType"
                )
                null
            }
        }.getOrElse { e ->
            Log.e(TAG, "Error creating media file: ${e.message}", e)
            null
        }
    }

    fun createMediaFile(
        context: Context,
        displayName: String,
        data: ByteArray,
        mimeType: String? = null
    ): Uri? {
        return runCatching {
            val mime = mimeType ?: getMimeTypeFromBytes(data)
            val relativePath = mime?.let { getRelativeForMimeType(mime) }
            return if (mime != null && relativePath != null) {
                val uri = findOrCreateMediaStoreEntry(
                    context,
                    null,
                    MediaDetails(displayName, mime, relativePath)
                )
                if (uri != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        createWriteRequest(context, uri, data = data)
                        uri
                    } else {
                        context.contentResolver.openOutputStream(uri, "w")?.use {
                            it.write(data)
                        }
                        uri
                    }
                } else {
                    Log.e(
                        TAG,
                        "Failed to create media entry at $relativePath: $displayName, $mimeType"
                    )
                    null
                }
            } else {
                Log.e(TAG, "Failed to create media file: Invalid relativePath and mimeType")
                null
            }
        }.getOrElse { e ->
            Log.e(TAG, "Error creating media file: ${e.message}", e)
            null
        }
    }

    fun copyMediaFileToRelative(
        context: Context,
        displayName: String,
        sourcePathOrUri: String,
        relativePath: String? = null,
        mimeType: String? = null
    ): Uri? {
        return runCatching {
            val sourceUri = resolveUriFromString(context, sourcePathOrUri)
            val mime = mimeType ?: sourceUri?.let { context.contentResolver.getType(it) }
            val relative = relativePath?.let {
                validateRelativePath(
                    relativePath
                )
            } ?: mime?.let { getRelativeForMimeType(mime) }

            ?: getMimeTypeFromFile(context, File(sourcePathOrUri))
            if (relative == null || sourceUri == null || mime == null) {
                Log.e(
                    TAG,
                    "Invalid inputs for copy: relativePath=$relative, sourceUri=$sourceUri, mimeType=$mime"
                )
                return@runCatching null
            }
            val destinationUri =
                findOrCreateMediaStoreEntry(
                    context,
                    null,
                    MediaDetails(displayName, mime, relative)
                )
            if (destinationUri == null) {
                Log.e(TAG, "Failed to create MediaStore entry for copy destination.")
                return@runCatching null
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                createWriteRequest(context, destinationUri, sourceUri = sourceUri)
                return@runCatching destinationUri
            } else {
                context.contentResolver.openInputStream(sourceUri)?.use { input ->
                    context.contentResolver.openOutputStream(destinationUri)?.use { output ->
                        input.copyTo(output) // Efficiently streams data from source to destination
                    }
                        ?: throw IOException("Failed to open output stream for destination URI: $destinationUri")
                } ?: throw IOException("Failed to open input stream for source URI: $sourceUri")
                return@runCatching destinationUri
            }
        }.getOrElse { e ->
            Log.e(TAG, "Error creating media file: ${e.message}", e)
            null
        }
    }

    fun copyMediaFileToPathOrUri(
        context: Context,
        toPathOrUri: String,
        fromPathOrUri: String,
        mimeType: String? = null
    ): Uri? {
        return runCatching {
            val toUri = resolveUriFromString(context, toPathOrUri)
            val fromUri = resolveUriFromString(context, fromPathOrUri)
            val collection = getStorageCollection(context, toUri.toString())
            if (toUri == null || fromUri == null || collection == null) {
                Log.e(
                    TAG,
                    "Invalid inputs for copy: destinationUri=$toUri, sourceUri=$fromUri, collection=$collection"
                )
                return null
            }
            val displayName = getDisplayName(context, fromPathOrUri)
            val mime =
                mimeType ?: context.contentResolver.getType(fromUri) ?: getMimeTypeFromFile(
                    context,
                    File(fromPathOrUri)
                )
            val relative = getRelativePath(context, fromUri.toString())
            if (displayName == null || relative == null || mime == null) {
                Log.e(TAG, "Failed to create MediaStore entry for copy destination.")
                return@runCatching null
            }
            val destinationUri = findOrCreateMediaStoreEntry(context, toUri.toString())
            if (destinationUri == null) {
                Log.e(TAG, "Failed to create MediaStore entry for copy destination.")
                return@runCatching null
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                createWriteRequest(context, destinationUri, sourceUri = fromUri)
                return@runCatching destinationUri
            } else {
                context.contentResolver.openInputStream(fromUri)?.use { input ->
                    context.contentResolver.openOutputStream(destinationUri)?.use { output ->
                        input.copyTo(output) // Efficiently streams data from source to destination
                    }
                        ?: throw IOException("Failed to open output stream for destination URI: $destinationUri")
                } ?: throw IOException("Failed to open input stream for source URI: $fromUri")
                return@runCatching destinationUri
            }
        }.getOrElse { e ->
            Log.e(TAG, "Error creating media file: ${e.message}", e)
            null
        }
    }

    /**
     * Execute pending write operations after permission granted
     */
    fun executePendingWriteOperations(): List<Uri>? {
        val operations = pendingWriteOperations.toList()
        pendingWriteOperations.clear()
        Log.d(TAG, "Execute Pending Write Operations: ${operations.size}")
        operations.all { operation ->
            runCatching {
                when {
                    operation.data != null -> {
                        Log.d(TAG, "Writing data to ${operation.destinationUri}")
                        activity.contentResolver.openOutputStream(operation.destinationUri, "w")
                            ?.use {
                                it.write(operation.data)
                            }
                        operation.onSuccess?.invoke(operation.destinationUri)
                        return operations.map { it.destinationUri }
                    }

                    operation.sourceUri != null -> {
                        runCatching {
                            Log.d(
                                TAG,
                                "Copying data from ${operation.sourceUri} to ${operation.destinationUri}"
                            )

                            val inputStream =
                                activity.contentResolver.openInputStream(operation.sourceUri)
                                    ?: throw IOException("Failed to open input stream for ${operation.sourceUri}")

                            val outputStream =
                                activity.contentResolver.openOutputStream(operation.destinationUri)
                                    ?: throw IOException("Failed to open output stream for ${operation.destinationUri}")

                            inputStream.use { input ->
                                outputStream.use { output ->
                                    val copiedBytes = input.copyTo(output)
                                    Log.d(TAG, "Successfully copied $copiedBytes bytes.")

                                    operation.onSuccess?.invoke(operation.destinationUri)
                                }
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val updateValues = ContentValues().apply {
                                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                                }
                                activity.contentResolver.update(
                                    operation.destinationUri,
                                    updateValues,
                                    null,
                                    null
                                )
                            }
                            return operations.map { it.destinationUri }
                        }.getOrElse { throwable ->
                            Log.e(
                                TAG,
                                "Error executing write operation for ${operation.sourceUri}",
                                throwable
                            )

                            val exception = throwable as? Exception ?: Exception(throwable)
                            operation.onFail?.invoke(exception)

                            return null
                        }
                    }

                    else -> {
                        operation.onFail?.invoke(IOException("No data source provided"))
                        Log.e(TAG, "No data source provided for write operation")
                        return null
                    }
                }
            }.getOrElse { e ->
                Log.e(TAG, "Error executing write operation: ${e.message}", e)
                operation.onFail?.invoke(e as Exception)
                return null
            }
        }
        return null
    }

    /**
     * Execute pending delete operations after permission granted
     */
    fun executePendingDeleteOperations(): Boolean {
        val operations = pendingDeleteOperations.toList()
        pendingDeleteOperations.clear()
        Log.d(TAG, "Execute Pending Delete Operations: ${operations.size}")
        return operations.all { operation ->
            runCatching {
                var deleted = activity.contentResolver.delete(operation.uri, null, null) > 0
                if (deleted) {
                    operation.onSuccess?.invoke()
                } else {
                    try {
                        deleted = File(operation.uri.toString()).deleteRecursively()
                    } catch (e: Exception) {
                        operation.onFail?.invoke(IOException("Failed to delete file"))
                        Log.e(TAG, "Error executing delete operation: ${e.message}", e)
                        deleted = false
                    }
                }
                deleted
            }.getOrElse { e ->
                Log.e(TAG, "Error executing delete operation: ${e.message}", e)
                operation.onFail?.invoke(e as Exception)
                false
            }
        }
    }

    // ────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ────────────────────────────────────────────────
    /**
     * Determines the MediaStore storage collection (e.g., "Pictures/", "Music/") for a given file path or URI string.
     * This acts as a dispatcher, delegating to more specific handlers based on the input type.
     *
     * @param context The application context.
     * @param pathOrUri A string that can be a file system path, a content:// URI from MediaStore,
     *                  or a content:// URI from a FileProvider.
     * @return A string representing the relative path collection (e.g., "Pictures/"), or null if it cannot be determined.
     */
    private fun getStorageCollection(context: Context, pathOrUri: String?): String? {
        if (pathOrUri == null) {
            return null
        }

        val uri = resolveUriFromString(context, pathOrUri) ?: return null

        return when (uri.authority?.lowercase()) {
            "media" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val mimeType = context.contentResolver.getType(uri)
                getCollectionForMimeType(mimeType).toString()
            } else {
                val file = File(pathOrUri)
                val mime = getMimeTypeFromFile(context, file)
                mime?.let { getCollectionForMimeType(it).toString() }
            }

            FILE_PROVIDER_AUTHORITY.lowercase() -> {
                val file = File(pathOrUri)
                val mime = getMimeTypeFromFile(context, file)
                mime?.let { getCollectionForMimeType(it).toString() }
            }

            "com.android.externalstorage.documents" -> {
                val path = parseDocumentUri(uri)
                path?.let { it ->
                    val mime = getMimeTypeFromFile(context, File(it))
                    mime?.let { getCollectionForMimeType(it).toString() }
                }
            }

            // Other authorities are not supported.
            else -> null
        }
    }

    private fun resolveUriFromString(context: Context, pathOrUri: String): Uri? {
        return if (pathOrUri.startsWith(CONTENT_URI_PREFIX)) {
            Uri.parse(pathOrUri)
        } else {
            pathToUri(context, pathOrUri) // Assuming pathToUri is a helper you have.
        }
    }

    /**
     * Parse DocumentsProvider URI to extract file path
     */
    private fun parseDocumentUri(uri: Uri): String? {
        val docId = DocumentsContract.getDocumentId(uri)
        val split = docId.split(":")

        return if (split.size >= 2) {
            val storageType = split[0]
            val relativePath = split[1]

            when (storageType) {
                "primary" -> {
                    // Primary internal storage
                    Environment.getExternalStorageDirectory().absolutePath + "/" + relativePath
                }

                "home" -> {
                    // User's home directory
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS).absolutePath + "/" + relativePath
                }

                else -> {
                    // Secondary storage or SD card
                    "/storage/$storageType/$relativePath"
                }
            }
        } else {
            null
        }
    }

    private fun validateRelativePath(relativePath: String): String? {
        val relative = "${relativePath.trim('/')}/"
        return MEDIA_DIRECTORIES[relative]
    }

    /** Helper to check if a MediaStore entry exists for a given URI. */
    private fun doesEntryExist(context: Context, uri: Uri): Boolean {
        // We only need to know if a row exists, so we don't need to query for any specific columns.
        return try {
            context.contentResolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns._ID),
                null,
                null,
                null
            )?.use { cursor ->
                cursor.moveToFirst() // Returns true if the cursor is not empty.
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error querying for existing MediaStore entry at $uri", e)
            false
        }
    }

    /** Helper to derive media details from a file path. */
    private fun getDetailsFromPath(context: Context, path: String): MediaDetails? {
        val file = File(path)
        if (!file.exists()) return null

        val displayName = getDisplayName(context, path)
        val mimeType = getMimeTypeFromFile(context, file)
        val relativePath = getRelativePath(context, path)

        // Ensure all required components were found.
        if (displayName == null || mimeType == null || relativePath == null) {
            return null
        }
        return MediaDetails(displayName, mimeType, relativePath)
    }

    /** Helper to create a new MediaStore entry. */
    private fun createNewMediaStoreEntry(context: Context, details: MediaDetails): Uri? {
        return try {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, details.displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, details.mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, details.relativePath)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            }
            val collection = getCollectionForMimeType(details.mimeType)
            val newUri = context.contentResolver.insert(collection, values)
            Log.d(TAG, "Successfully created new MediaStore entry: $newUri")
            newUri
        } catch (e: Exception) {
            Log.e(TAG, "Error creating new MediaStore entry", e)
            null
        }
    }

    /**
     * BASIC: Creates only the MediaStore entry (no data writing)
     */
    fun findOrCreateMediaStoreEntry(
        context: Context,
        pathOrUri: String? = null,
        mediaDetails: MediaDetails? = null
    ): Uri? {
        if (pathOrUri == null && mediaDetails == null) {
            Log.e(TAG, "Both pathOrUri and mediaDetails cannot be null.")
            return null
        }
        pathOrUri?.let { pathString ->
            resolveUriFromString(context, pathString)?.let { uri ->
                if (doesEntryExist(context, uri)) {
                    Log.d(TAG, "Found existing MediaStore entry: $uri")
                    return uri
                }
            }
        }
        val detailsToCreate = mediaDetails ?: pathOrUri?.let {
            getDetailsFromPath(context, it)
        }

        if (detailsToCreate == null) {
            Log.e(TAG, "Could not determine media details needed for creation.")
            return null
        }

        return createNewMediaStoreEntry(context, detailsToCreate)
    }

    /**
     * Request write permission using createWriteRequest (Android 11+)
     */
    @RequiresApi(Build.VERSION_CODES.R)
    private fun createWriteRequest(
        context: Context,
        destinationUri: Uri,
        data: ByteArray? = null,
        sourceUri: Uri? = null,
        onSuccess: ((Uri?) -> Unit)? = null,
        onFail: ((Exception) -> Unit)? = null
    ) {
        runCatching {
            val pendingIntent =
                MediaStore.createWriteRequest(context.contentResolver, listOf(destinationUri))
            // Add to pending operations queue
            pendingWriteOperations.add(
                WriteOperation(
                    destinationUri,
                    data,
                    sourceUri,
                    onSuccess,
                    onFail
                )
            )
            activity.startIntentSenderForResult(
                pendingIntent.intentSender,
                WRITE_REQUEST_CODE,
                null,
                0,
                0,
                0,
                null
            )
        }.onSuccess {
            onSuccess?.invoke(destinationUri)
        }.onFailure { e ->
            {
                when (e) {
                    is PendingIntent.CanceledException -> {
                        Log.e(TAG, "Write permission request canceled for URI: $destinationUri", e)
                    }

                    is SecurityException -> {
                        val recoverableSecurityException = e as? RecoverableSecurityException
                        val intentSender =
                            recoverableSecurityException?.userAction?.actionIntent?.intentSender
                        if (intentSender != null) {
                            activity.startIntentSenderForResult(
                                intentSender, WRITE_REQUEST_CODE,
                                Intent(destinationUri.toString()), 0, 0, 0, null
                            )
                        } else
                            Log.e(TAG, "Error requesting write permission: ${e.message}", e)
                    }

                    else -> {
                        Log.e(TAG, "Error requesting write permission: ${e.message}", e)
                    }
                }
            }
            onFail?.invoke(e as Exception)
        }
    }

    /**
     * Request delete permission using createDeleteRequest (Android 11+)
     */
    private fun createDeleteRequest(
        context: Context,
        uri: Uri,
        onSuccess: (() -> Unit)? = null,
        onFail: ((Exception) -> Unit)? = null
    ) {
        runCatching {
            // Add to pending operations queue
            pendingDeleteOperations.add(DeleteOperation(uri, onSuccess, onFail))
            val cursor = context.contentResolver.query(uri, null, null, null, null)
                ?: throw Exception("Could not find requested file $uri")
            cursor.use {
                if (!it.moveToFirst()) throw Exception("Could not find requested file $uri")
            }
            cursor.close()
            when (Build.VERSION.SDK_INT) {
                Build.VERSION_CODES.R -> {
                    val pendingIntent =
                        MediaStore.createDeleteRequest(context.contentResolver, listOf(uri))
                    activity.startIntentSenderForResult(
                        pendingIntent.intentSender,
                        DELETE_REQUEST_CODE,
                        null,
                        0,
                        0,
                        0,
                        null
                    )
                }

                Build.VERSION_CODES.Q -> {
                    activity.contentResolver.delete(uri, null, null)
                }

                else -> {

                }
            }
        }.onSuccess {
            onSuccess?.invoke()
        }.onFailure { e ->
            when (e) {
                is PendingIntent.CanceledException -> {
                    Log.e(TAG, "Delete permission request canceled for URI: $uri", e)
                }

                is SecurityException -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        val recoverableSecurityException = e as? RecoverableSecurityException
                        val intentSender =
                            recoverableSecurityException?.userAction?.actionIntent?.intentSender
                        if (intentSender != null) {
                            activity.startIntentSenderForResult(
                                intentSender, DELETE_REQUEST_CODE,
                                Intent(uri.toString()), 0, 0, 0, null
                            )
                        }
                    } else
                        Log.e(TAG, "Error requesting delete permission: ${e.message}", e)
                }

                else -> {
                    Log.e(TAG, "Error occurred when deleting file: ${e.message}", e)
                }
            }
            onFail?.invoke(e as Exception)
        }
    }

    private fun getMimeTypeFromFile(context: Context, file: File): String? {
        val uri = Uri.fromFile(file)
        val type = context.contentResolver.getType(uri)
        if (!type.isNullOrEmpty()) return type
        val ext = file.extension.lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
    }

    private fun getMimeTypeFromBytes(data: ByteArray): String? {
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


    /**
     * Returns the appropriate primary external storage collection Uri for a given MIME type.
     *
     * This function selects the collection based on the file's general category (image, video, audio).
     * For all other file types, it provides a version-aware fallback:
     * - On API 29 (Android 10) and newer, it returns the Downloads collection.
     * - On older versions, it returns the general Files collection.
     */
    private fun getCollectionForMimeType(mimeType: String?): Uri {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            when {
                mimeType?.startsWith("image/") == true ->
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI

                mimeType?.startsWith("video/") == true ->
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI

                mimeType?.startsWith("audio/") == true ->
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

                else ->
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI
            }
        } else
            MediaStore.Files.getContentUri("external")
    }

    private fun getRelativeForMimeType(mimeType: String): String {
        return when {
            mimeType.startsWith("image/") ->
                Environment.DIRECTORY_PICTURES

            mimeType.startsWith("video/") ->
                Environment.DIRECTORY_MOVIES

            mimeType.startsWith("audio/") ->
                Environment.DIRECTORY_MUSIC

            else ->
                Environment.DIRECTORY_DOWNLOADS
        }
    }

    private fun getRelativePath(context: Context, pathOrUri: String): String? {
        val uri = resolveUriFromString(context, pathOrUri)
        return uri?.let {
            when {
                uri.authority == "media" -> {
                    val cursor = activity.contentResolver.query(uri, null, null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val index = it.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
                            if (index != -1) {
                                it.getString(index)
                            } else
                                null
                        } else {
                            null
                        }
                    }
                }

                else -> {
                    val mime = getMimeTypeFromFile(context, File(pathOrUri))
                    mime?.let { mimeType -> getRelativeForMimeType(mimeType) }
                }
            }
        }
    }

    /**
     * Gets the display name of a file from a path or URI, without the extension.
     *
     * @param context The application context.
     * @param pathOrUri The file path or content URI string.
     * @return The display name without its extension, or null if it cannot be determined.
     */
    private fun getDisplayName(context: Context, pathOrUri: String): String? {
        val fullName: String? = if (pathOrUri.startsWith(CONTENT_URI_PREFIX)) {
            try {
                context.contentResolver.query(
                    Uri.parse(pathOrUri),
                    arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                    null,
                    null,
                    null
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        cursor.getString(0)
                    } else {
                        null
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not get display name from URI, falling back to path parsing.", e)
                Uri.parse(pathOrUri).path?.let { File(it).name }
            }
        } else {
            File(pathOrUri).name
        }

        return fullName?.let { File(it).nameWithoutExtension }
    }

    // Extension function for cleaner prefix removal
    private fun String.removePrefixIfStartsWith(prefix: String): String {
        return if (this.startsWith("$prefix/")) {
            this.replace("$prefix/", "")
        } else if (this.startsWith(prefix)) {
            this.replace(prefix, "")
        } else {
            this
        }
    }
}