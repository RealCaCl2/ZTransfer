package com.cacl2.ztransfer.camera

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

/**
 * Simple JSON-file-based project metadata store.
 *
 * Projects are persisted as a JSON array in the app's private external
 * files directory.  Each project's photos live in a subdirectory named
 * after the project ID under the Downloads root.
 *
 * Thread-safe: all public methods synchronise on [lock].
 */
class ProjectStore(context: Context) {

    // Use application context + internal storage for reliability
    private val appContext = context.applicationContext

    data class Project(
        val id: String,
        val name: String,
        val coverPhotoPath: String?,
        val createdAt: Long,
        val updatedAt: Long,
        val photoCount: Int
    )

    private val lock = Any()
    private val prefsKey = "active_project_id"

    /** Root directory where project metadata + photos live. */
    val projectsRoot: File
        get() = File(appContext.getExternalFilesDir(null), "Projects")

    private val storeFile: File
        get() = File(projectsRoot, "_projects.json")

    // ── Migration ────────────────────────────────────────────────────────────

    /** Create a default project for existing legacy photos if needed. */
    fun migrateIfNeeded(): Project? {
        val existing = listProjects()
        if (existing.isNotEmpty()) return null

        // Check for legacy photos
        val legacyDir = File(appContext.getExternalFilesDir(null), "Downloads")
        val hasLegacyPhotos = legacyDir.exists() &&
            legacyDir.listFiles()?.any {
                it.name.endsWith(".JPG", true) || it.name.endsWith(".JPEG", true) || it.name.endsWith(".NEF", true)
            } == true

        if (hasLegacyPhotos) {
            val p = createProject("Default Project")
            // Move legacy photos into the project folder
            val targetDir = projectDir(p.id)
            legacyDir.listFiles()?.forEach { file ->
                if (file.isFile) {
                    file.copyTo(File(targetDir, file.name), overwrite = false)
                    file.delete()
                }
            }
            // Update photo count and cover
            val photos = targetDir.listFiles()?.filter {
                it.name.endsWith(".JPG", true) || it.name.endsWith(".JPEG", true) || it.name.endsWith(".NEF", true)
            } ?: emptyList()
            if (photos.isNotEmpty()) {
                onPhotoSaved(p.id, photos.first().absolutePath)
                repeat(photos.size - 1) { onPhotoSaved(p.id, "") }
            }
            Log.d(TAG, "Migrated ${photos.size} legacy photos to: ${p.id}")
            return getProject(p.id)
        }
        return null
    }

    // ── CRUD ──────────────────────────────────────────────────────────────────

    fun listProjects(): List<Project> = synchronized(lock) {
        ensureRoot()
        val json = loadJson() ?: return emptyList()
        val list = mutableListOf<Project>()
        for (i in 0 until json.length()) {
            list.add(parseProject(json.getJSONObject(i)))
        }
        list.sortedByDescending { it.updatedAt }
    }

    fun getProject(id: String): Project? = synchronized(lock) {
        listProjects().find { it.id == id }
    }

    fun createProject(name: String): Project = synchronized(lock) {
        ensureRoot()
        val now = System.currentTimeMillis()
        val project = Project(
            id = UUID.randomUUID().toString().take(8),
            name = name,
            coverPhotoPath = null,
            createdAt = now,
            updatedAt = now,
            photoCount = 0
        )
        val json = loadJson() ?: JSONArray()
        json.put(projectToJson(project))
        saveJson(json)
        ensureProjectDir(project)
        Log.d(TAG, "Created project: ${project.id} ($name)")
        project
    }

    fun updateProject(id: String, name: String): Project? = synchronized(lock) {
        val json = loadJson() ?: return@synchronized null
        var found: Project? = null
        for (i in 0 until json.length()) {
            val obj = json.getJSONObject(i)
            if (obj.getString("id") == id) {
                obj.put("name", name)
                obj.put("updatedAt", System.currentTimeMillis())
                found = parseProject(obj)
                break
            }
        }
        if (found != null) saveJson(json)
        found
    }

    fun deleteProject(id: String, deletePhotos: Boolean): Boolean =
        synchronized(lock) {
            val json = loadJson() ?: return false
            var removed: Project? = null
            val newJson = JSONArray()
            for (i in 0 until json.length()) {
                val obj = json.getJSONObject(i)
                if (obj.getString("id") == id) {
                    removed = parseProject(obj)
                } else {
                    newJson.put(obj)
                }
            }
            if (removed == null) return false
            saveJson(newJson)

            if (deletePhotos) {
                projectDir(id).deleteRecursively()
            }
            // Clear active project if it was deleted
            if (getActiveProjectId() == id) {
                setActiveProjectId(null)
            }
            true
        }

    /** Get the directory where a project's photos are stored. */
    fun projectDir(projectId: String): File {
        return File(projectsRoot, projectId)
    }

    /** Update photo count and cover for a project after a new photo is saved. */
    fun onPhotoSaved(projectId: String, photoPath: String) {
        synchronized(lock) {
            val json = loadJson() ?: return
            for (i in 0 until json.length()) {
                val obj = json.getJSONObject(i)
                if (obj.getString("id") == projectId) {
                    obj.put("photoCount", obj.optInt("photoCount", 0) + 1)
                    obj.put("updatedAt", System.currentTimeMillis())
                    if (obj.optString("coverPhotoPath", "").isEmpty()) {
                        obj.put("coverPhotoPath", photoPath)
                    }
                    break
                }
            }
            saveJson(json)
        }
    }

    fun onPhotoDeleted(projectId: String, count: Int) {
        synchronized(lock) {
            val json = loadJson() ?: return
            for (i in 0 until json.length()) {
                val obj = json.getJSONObject(i)
                if (obj.getString("id") == projectId) {
                    val current = obj.optInt("photoCount", 0)
                    obj.put("photoCount", maxOf(0, current - count))
                    obj.put("updatedAt", System.currentTimeMillis())
                    break
                }
            }
            saveJson(json)
        }
    }

    // ── Active project ────────────────────────────────────────────────────────

    fun getActiveProjectId(): String? {
        return appContext.getSharedPreferences("ztransfer", Context.MODE_PRIVATE)
            .getString(prefsKey, null)
    }

    fun setActiveProjectId(id: String?) {
        appContext.getSharedPreferences("ztransfer", Context.MODE_PRIVATE)
            .edit().putString(prefsKey, id).apply()
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private fun ensureRoot() {
        if (!projectsRoot.exists()) projectsRoot.mkdirs()
    }

    private fun ensureProjectDir(project: Project) {
        projectDir(project.id).mkdirs()
    }

    private fun loadJson(): JSONArray? {
        return try {
            if (!storeFile.exists()) return null
            JSONArray(storeFile.readText())
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load projects", e)
            null
        }
    }

    private fun saveJson(json: JSONArray) {
        try {
            storeFile.writeText(json.toString(2))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save projects", e)
        }
    }

    private fun parseProject(obj: JSONObject): Project {
        return Project(
            id = obj.getString("id"),
            name = obj.getString("name"),
            coverPhotoPath = obj.optString("coverPhotoPath", null),
            createdAt = obj.optLong("createdAt", 0),
            updatedAt = obj.optLong("updatedAt", 0),
            photoCount = obj.optInt("photoCount", 0)
        )
    }

    private fun projectToJson(p: Project): JSONObject {
        return JSONObject().apply {
            put("id", p.id)
            put("name", p.name)
            put("coverPhotoPath", p.coverPhotoPath ?: "")
            put("createdAt", p.createdAt)
            put("updatedAt", p.updatedAt)
            put("photoCount", p.photoCount)
        }
    }

    companion object {
        private const val TAG = "ProjectStore"
    }
}
