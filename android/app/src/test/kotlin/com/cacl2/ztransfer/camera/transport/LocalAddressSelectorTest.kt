package com.cacl2.ztransfer.camera.transport

import java.net.Inet4Address
import java.net.InetAddress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalAddressSelectorTest {
    @Test
    fun `selects hotspot address in the camera subnet instead of wifi sta`() {
        val selected = LocalAddressSelector.select(
            target = ipv4("192.168.6.131"),
            candidates = listOf(
                route("192.168.0.27", 24, "wlan0"),
                route("192.168.6.1", 24, "wlan1"),
            ),
        )

        assertEquals("192.168.6.1", selected?.address?.hostAddress)
        assertEquals("wlan1", selected?.interfaceName)
    }

    @Test
    fun `uses longest matching prefix when several local routes cover target`() {
        val selected = LocalAddressSelector.select(
            target = ipv4("192.168.6.131"),
            candidates = listOf(
                route("192.168.0.27", 16, "broad-route"),
                route("192.168.6.1", 24, "hotspot-route"),
            ),
        )

        assertEquals("hotspot-route", selected?.interfaceName)
    }

    @Test
    fun `prefers source address proven by discovery even with host prefix`() {
        val hotspotAddress = ipv4("10.35.102.166")
        val selected = LocalAddressSelector.select(
            target = ipv4("10.35.102.200"),
            candidates = listOf(
                route("192.168.0.105", 24, "wlan0"),
                LocalIpv4Route(hotspotAddress, 32, "ap0"),
            ),
            preferredAddress = hotspotAddress,
        )

        assertEquals("10.35.102.166", selected?.address?.hostAddress)
        assertEquals("ap0", selected?.interfaceName)
    }

    @Test
    fun `falls back to hotspot slash 24 when android reports host prefix`() {
        val selected = LocalAddressSelector.select(
            target = ipv4("10.35.102.200"),
            candidates = listOf(
                route("192.168.0.105", 24, "wlan0"),
                route("10.35.102.166", 32, "ap0"),
            ),
        )

        assertEquals("10.35.102.166", selected?.address?.hostAddress)
        assertEquals("ap0", selected?.interfaceName)
    }

    @Test
    fun `returns null when no local subnet reaches camera`() {
        val selected = LocalAddressSelector.select(
            target = ipv4("192.168.6.131"),
            candidates = listOf(
                route("192.168.0.27", 24, "wlan0"),
                route("10.0.0.1", 24, "ethernet"),
            ),
        )

        assertNull(selected)
    }

    @Test
    fun `matches non byte aligned prefixes`() {
        assertTrue(
            LocalAddressSelector.sharesSubnet(
                ipv4("172.20.16.1"),
                ipv4("172.20.31.254"),
                20,
            ),
        )
        assertFalse(
            LocalAddressSelector.sharesSubnet(
                ipv4("172.20.16.1"),
                ipv4("172.20.32.1"),
                20,
            ),
        )
    }

    @Test
    fun `ignores invalid prefix lengths`() {
        val selected = LocalAddressSelector.select(
            target = ipv4("192.168.6.131"),
            candidates = listOf(route("192.168.6.1", 0, "invalid")),
        )

        assertNull(selected)
    }

    private fun route(address: String, prefixLength: Int, interfaceName: String) =
        LocalIpv4Route(ipv4(address), prefixLength, interfaceName)

    private fun ipv4(address: String): Inet4Address =
        InetAddress.getByName(address) as Inet4Address
}
