package com.cacl2.ztransfer.camera.transport

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NetworkRouteSelectorTest {
    @Test
    fun `resolved hotspot target without a registered route uses system routing`() {
        val selected = NetworkRouteSelector.select(
            candidates = listOf("unrelated-wifi-sta"),
            active = "unrelated-wifi-sta",
            targetResolved = true,
            routeMatches = { false },
        )

        assertNull(selected)
    }

    @Test
    fun `resolved target binds only to the network whose route matches`() {
        val selected = NetworkRouteSelector.select(
            candidates = listOf("unrelated-wifi-sta", "camera-network"),
            active = "unrelated-wifi-sta",
            targetResolved = true,
            routeMatches = { it == "camera-network" },
        )

        assertEquals("camera-network", selected)
    }

    @Test
    fun `unresolved hostname retains the active wifi fallback`() {
        val selected = NetworkRouteSelector.select(
            candidates = listOf("fallback-wifi", "active-wifi"),
            active = "active-wifi",
            targetResolved = false,
            routeMatches = { false },
        )

        assertEquals("active-wifi", selected)
    }
}
