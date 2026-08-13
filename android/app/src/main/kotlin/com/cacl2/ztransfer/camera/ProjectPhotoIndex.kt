package com.cacl2.ztransfer.camera

import java.io.File

internal data class ProjectPhotoSnapshot(
    val photoCount: Int,
    val coverPhotoPath: String?,
    val newestModifiedAt: Long,
)

/** Derives project metadata from the files that actually exist on disk. */
internal object ProjectPhotoIndex {
    fun scan(directory: File): ProjectPhotoSnapshot {
        val photos = directory.listFiles()
            ?.asSequence()
            ?.filter { it.isFile && isSupportedPhoto(it) }
            ?.toList()
            .orEmpty()
        val newest = photos.maxByOrNull { it.lastModified() }
        return ProjectPhotoSnapshot(
            photoCount = photos.size,
            coverPhotoPath = newest?.absolutePath,
            newestModifiedAt = newest?.lastModified() ?: 0L,
        )
    }

    fun isSupportedPhoto(file: File): Boolean = when (file.extension.lowercase()) {
        "jpg", "jpeg", "nef" -> true
        else -> false
    }
}
