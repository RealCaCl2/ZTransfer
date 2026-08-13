package com.cacl2.ztransfer.camera.transport

import java.net.InetAddress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NetworkRouteSelectorTest {
    @Test
    fun `resolved hotspot target does not bind an unrelated Android network`() {
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

    @Test
    fun `default route is not treated as a direct camera subnet`() {
        assertFalse(
            NetworkRouteSelector.matchesDirectIpv4Route(
                target = InetAddress.getByName("10.35.102.200"),
                destination = InetAddress.getByName("0.0.0.0"),
                prefixLength = 0,
            ),
        )
    }

    @Test
    fun `matching hotspot subnet is treated as a direct route`() {
        assertTrue(
            NetworkRouteSelector.matchesDirectIpv4Route(
                target = InetAddress.getByName("10.35.102.200"),
                destination = InetAddress.getByName("10.35.102.0"),
                prefixLength = 24,
            ),
        )
    }

    @Test
    fun `unrelated wifi subnet is not treated as a direct route`() {
        assertFalse(
            NetworkRouteSelector.matchesDirectIpv4Route(
                target = InetAddress.getByName("10.35.102.200"),
                destination = InetAddress.getByName("192.168.0.0"),
                prefixLength = 24,
            ),
        )
    }
}
