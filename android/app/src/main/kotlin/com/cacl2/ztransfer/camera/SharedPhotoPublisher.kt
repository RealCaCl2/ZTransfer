package com.cacl2.ztransfer.camera

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import java.io.File

/** Publishes private working copies into shared Pictures so galleries and file managers can see them. */
object SharedPhotoPublisher {
    private const val TAG = "SharedPhotoPublisher"

    fun publish(context: Context, source: File): Uri? {
        if (!source.isFile || !ProjectPhotoIndex.isSupportedPhoto(source)) return null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            MediaScannerConnection.scanFile(
                context,
                arrayOf(source.absolutePath),
                arrayOf(mimeType(source)),
                null,
            )
            return null
        }

        val resolver = context.applicationContext.contentResolver
        val collection = collectionFor(source)
        val relativePath = sharedRelativePath(source)
        findExisting(context, collection, relativePath, source)?.let { return it }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, source.name)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType(source))
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(collection, values) ?: return null
        return try {
            val output = resolver.openOutputStream(uri, "w")
                ?: throw IllegalStateException("MediaStore output stream is unavailable")
            source.inputStream().use { input ->
                output.use { input.copyTo(it) }
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            Log.i(TAG, "Published ${source.name} to $relativePath")
            uri
        } catch (error: Exception) {
            runCatching { resolver.delete(uri, null, null) }
            Log.w(TAG, "Failed to publish ${source.absolutePath}", error)
            null
        }
    }

    /** Backfill photos saved by older versions into shared storage. */
    fun publishExistingPhotos(context: Context) {
        val base = context.getExternalFilesDir(null) ?: return
        val directories = buildList {
            add(File(base, "Downloads"))
            File(base, "Projects").listFiles()
                ?.filterTo(this) { it.isDirectory }
        }
        directories.forEach { directory ->
            directory.listFiles()
                ?.filter { it.isFile && ProjectPhotoIndex.isSupportedPhoto(it) }
                ?.forEach { publish(context, it) }
        }
    }

    private fun findExisting(
        context: Context,
        collection: Uri,
        relativePath: String,
        source: File,
    ): Uri? {
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection =
            "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND " +
                "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND " +
                "${MediaStore.MediaColumns.SIZE}=?"
        val args = arrayOf(source.name, relativePath, source.length().toString())
        return context.contentResolver.query(collection, projection, selection, args, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                ContentUris.withAppendedId(collection, cursor.getLong(0))
            }
    }

    private fun sharedRelativePath(source: File): String {
        val parent = source.parentFile
        val projectSegment = if (parent?.parentFile?.name == "Projects") {
            parent.name
        } else {
            "Unsorted"
        }.replace(Regex("[^A-Za-z0-9._-]"), "_")
        return "${Environment.DIRECTORY_PICTURES}/ZTransfer/$projectSegment/"
    }

    private fun mimeType(source: File): String =
        if (source.extension.equals("nef", true)) "image/x-nikon-nef" else "image/jpeg"

    private fun collectionFor(source: File): Uri =
        if (source.extension.equals("nef", true)) {
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        }
}
