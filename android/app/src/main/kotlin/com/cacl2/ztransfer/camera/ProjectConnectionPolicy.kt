package com.cacl2.ztransfer.camera

/** Keeps camera sessions tied to an existing project. */
internal object ProjectConnectionPolicy {
    fun selectActiveProjectId(
        projectIds: List<String>,
        currentProjectId: String?,
    ): String? {
        if (projectIds.isEmpty()) return null
        return currentProjectId?.takeIf(projectIds::contains) ?: projectIds.first()
    }
}
