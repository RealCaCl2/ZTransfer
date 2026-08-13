package com.cacl2.ztransfer.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ProjectConnectionPolicyTest {
    @Test
    fun `rejects connection when no project exists`() {
        assertNull(ProjectConnectionPolicy.selectActiveProjectId(emptyList(), "stale"))
    }

    @Test
    fun `keeps an active project that still exists`() {
        assertEquals(
            "second",
            ProjectConnectionPolicy.selectActiveProjectId(
                listOf("first", "second"),
                "second",
            ),
        )
    }

    @Test
    fun `selects first project when active id is missing or stale`() {
        assertEquals(
            "first",
            ProjectConnectionPolicy.selectActiveProjectId(
                listOf("first", "second"),
                "deleted",
            ),
        )
    }
}
