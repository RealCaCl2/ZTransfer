package com.cacl2.ztransfer.camera

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persisted pairing profile. Its active-profile behavior follows the reference flow's
 * s5/v5 store and retains everything needed to reconnect without re-pairing.
 */
data class CameraProfile(
    val id: String,
    val cameraName: String,
    val cameraGuidHex: String,
    val lastIp: String,
    val port: Int,
    val clientGuidHex: String,
    val initiatorName: String,
    val timestamp: Long,
    val verified: Boolean = false
)

class CameraProfileStore(context: Context) {
    companion object {
        private const val PREFS_NAME = "ztransfer_camera_profiles"
        private const val KEY_PROFILES = "profiles"
        private const val KEY_ACTIVE_PROFILE_ID = "active_profile_id"
        private const val TAG = "CameraProfileStore"
    }

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    @Synchronized
    fun saveProfile(profile: CameraProfile) {
        val profiles = loadAll().toMutableList()
        profiles.removeAll {
            it.id == profile.id ||
                it.cameraGuidHex.equals(profile.cameraGuidHex, ignoreCase = true)
        }
        profiles.add(0, profile)
        writeProfiles(profiles, activeProfileId = profile.id)
        Log.d(TAG, "Saved profile: ${profile.cameraName} @ ${profile.lastIp}")
    }

    fun loadAll(): List<CameraProfile> {
        val jsonStr = prefs.getString(KEY_PROFILES, null) ?: return emptyList()
        return try {
            val arr = JSONArray(jsonStr)
            (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                CameraProfile(
                    id = obj.getString("id"),
                    cameraName = obj.optString("cameraName", ""),
                    cameraGuidHex = obj.optString("cameraGuidHex", ""),
                    lastIp = obj.optString("lastIp", ""),
                    port = obj.optInt("port", 15740),
                    clientGuidHex = obj.optString("clientGuidHex", ""),
                    initiatorName = obj.optString("initiatorName", "ZTransfer"),
                    timestamp = obj.optLong("timestamp", 0),
                    verified = obj.optBoolean("verified", false)
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load profiles", e)
            emptyList()
        }
    }

    fun getActiveProfileId(): String =
        prefs.getString(KEY_ACTIVE_PROFILE_ID, "").orEmpty()

    fun getById(id: String): CameraProfile? =
        loadAll().firstOrNull { it.id == id }

    /**
     * Follows the reference active-profile lookup: use the explicitly selected
     * profile first, then the most recently used profile for legacy installs.
     */
    fun getActiveProfile(): CameraProfile? {
        val profiles = loadAll()
        if (profiles.isEmpty()) return null
        val activeId = getActiveProfileId()
        return profiles.firstOrNull { it.id == activeId }
            ?: profiles.maxByOrNull { it.timestamp }
    }

    fun findByIp(ip: String): CameraProfile? =
        loadAll().firstOrNull { it.lastIp == ip }

    @Synchronized
    fun setActiveProfile(id: String): Boolean {
        if (getById(id) == null) return false
        prefs.edit().putString(KEY_ACTIVE_PROFILE_ID, id).apply()
        return true
    }

    @Synchronized
    fun recordConnection(id: String, ip: String, cameraName: String?) {
        val profiles = loadAll().toMutableList()
        val index = profiles.indexOfFirst { it.id == id }
        if (index < 0) return

        val old = profiles.removeAt(index)
        profiles.add(
            0,
            old.copy(
                cameraName = cameraName?.takeIf { it.isNotBlank() } ?: old.cameraName,
                lastIp = ip.ifBlank { old.lastIp },
                timestamp = System.currentTimeMillis(),
            ),
        )
        writeProfiles(profiles, activeProfileId = old.id)
    }

    @Synchronized
    fun removeProfile(id: String) {
        val profiles = loadAll().toMutableList()
        profiles.removeAll { it.id == id }
        val activeId = getActiveProfileId()
        val nextActiveId = if (activeId == id) {
            profiles.maxByOrNull { it.timestamp }?.id
        } else {
            activeId
        }
        writeProfiles(profiles, activeProfileId = nextActiveId)
    }

    @Synchronized
    fun markVerified(id: String) {
        val profiles = loadAll().toMutableList()
        val idx = profiles.indexOfFirst { it.id == id }
        if (idx >= 0) {
            profiles[idx] = profiles[idx].copy(verified = true)
            writeProfiles(profiles, activeProfileId = getActiveProfileId())
        }
    }

    private fun writeProfiles(profiles: List<CameraProfile>, activeProfileId: String?) {
        val json = JSONArray()
        for (profile in profiles) {
            json.put(JSONObject().apply {
                put("id", profile.id)
                put("cameraName", profile.cameraName)
                put("cameraGuidHex", profile.cameraGuidHex)
                put("lastIp", profile.lastIp)
                put("port", profile.port)
                put("clientGuidHex", profile.clientGuidHex)
                put("initiatorName", profile.initiatorName)
                put("timestamp", profile.timestamp)
                put("verified", profile.verified)
            })
        }

        prefs.edit().apply {
            putString(KEY_PROFILES, json.toString())
            if (activeProfileId.isNullOrBlank()) {
                remove(KEY_ACTIVE_PROFILE_ID)
            } else {
                putString(KEY_ACTIVE_PROFILE_ID, activeProfileId)
            }
        }.apply()
    }
}
