package com.cacl2.ztransfer.camera.transport

import java.net.Inet4Address

internal data class LocalIpv4Route(
    val address: Inet4Address,
    val prefixLength: Int,
    val interfaceName: String,
)

/** Selects the most specific local IPv4 address that can directly reach a target subnet. */
internal object LocalAddressSelector {
    fun select(
        target: Inet4Address,
        candidates: List<LocalIpv4Route>,
        preferredAddress: Inet4Address? = null,
    ): LocalIpv4Route? {
        val usableCandidates = candidates.filter { it.prefixLength in 1..32 }
        preferredAddress?.let { preferred ->
            usableCandidates.firstOrNull { it.address == preferred }?.let { return it }
        }

        val routedMatch = usableCandidates
            .asSequence()
            .filter { sharesSubnet(it.address, target, it.prefixLength) }
            .maxByOrNull { it.prefixLength }
        if (routedMatch != null) return routedMatch

        // Android hotspot interfaces on some OEM builds are exposed with a host prefix (/32),
        // while tethering still leases clients from the surrounding /24. CameraScanner uses that
        // same /24 to discover the target, so retain it as a final direct-LAN fallback.
        return usableCandidates.firstOrNull { sharesSubnet(it.address, target, 24) }
    }

    internal fun sharesSubnet(
        local: Inet4Address,
        target: Inet4Address,
        prefixLength: Int,
    ): Boolean {
        if (prefixLength !in 1..32) return false

        val localBytes = local.address
        val targetBytes = target.address
        val wholeBytes = prefixLength / 8
        val remainingBits = prefixLength % 8

        for (index in 0 until wholeBytes) {
            if (localBytes[index] != targetBytes[index]) return false
        }

        if (remainingBits == 0) return true

        val mask = (0xff shl (8 - remainingBits)) and 0xff
        return (localBytes[wholeBytes].toInt() and mask) ==
            (targetBytes[wholeBytes].toInt() and mask)
    }
}
