package com.cacl2.ztransfer.camera.transport

import java.net.Inet4Address
import java.net.InetAddress

/**
 * Chooses an Android network only when it is safe to bind a socket to it.
 *
 * A phone hotspot interface is commonly absent from ConnectivityManager's Wi-Fi networks. In that
 * topology the hotspot route is missing from the candidate list, while binding to an unrelated
 * Wi-Fi STA network makes the same host time out. A resolved target must therefore never fall back
 * to an arbitrary candidate that has no route for that address. The caller can then bind a normal
 * socket to a matching, unregistered hotspot interface address.
 */
internal object NetworkRouteSelector {
    fun <T> select(
        candidates: List<T>,
        active: T?,
        targetResolved: Boolean,
        routeMatches: (T) -> Boolean,
    ): T? {
        if (targetResolved) {
            return candidates.firstOrNull(routeMatches)
        }

        return active?.takeIf { it in candidates } ?: candidates.firstOrNull()
    }

    /**
     * Whether an Android route represents the target's directly-connected IPv4 subnet.
     *
     * A default route (0.0.0.0/0) matches every IPv4 address according to RouteInfo.matches().
     * It must not choose an unrelated Wi-Fi STA network over an unregistered hotspot interface.
     */
    fun matchesDirectIpv4Route(
        target: InetAddress,
        destination: InetAddress,
        prefixLength: Int,
    ): Boolean {
        if (target !is Inet4Address || destination !is Inet4Address) return false
        if (prefixLength !in 1..32) return false
        return LocalAddressSelector.sharesSubnet(destination, target, prefixLength)
    }
}
