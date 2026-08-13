package com.cacl2.ztransfer.camera

import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ProjectPhotoIndexTest {
    @Test
    fun `counts supported photos from disk and selects newest cover`() {
        val directory = Files.createTempDirectory("ztransfer-project").toFile()
        try {
            val older = directory.resolve("DSC_0001.JPG").apply {
                writeBytes(byteArrayOf(1))
                setLastModified(1_000L)
            }
            val newer = directory.resolve("DSC_0002.NEF").apply {
                writeBytes(byteArrayOf(2))
                setLastModified(2_000L)
            }
            directory.resolve("transfer.part").writeBytes(byteArrayOf(3))

            val snapshot = ProjectPhotoIndex.scan(directory)

            assertEquals(2, snapshot.photoCount)
            assertEquals(newer.absolutePath, snapshot.coverPhotoPath)
            assertEquals(2_000L, snapshot.newestModifiedAt)
            assertEquals(true, older.isFile)
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun `empty or missing directory has zero photos`() {
        val directory = Files.createTempDirectory("ztransfer-empty").toFile()
        directory.deleteRecursively()

        val snapshot = ProjectPhotoIndex.scan(directory)

        assertEquals(0, snapshot.photoCount)
        assertNull(snapshot.coverPhotoPath)
        assertEquals(0L, snapshot.newestModifiedAt)
    }
}
