package com.cacl2.ztransfer.camera.transport

/**
 * Chooses an Android network only when it is safe to bind a socket to it.
 *
 * A phone hotspot interface is commonly absent from ConnectivityManager's Wi-Fi networks. In that
 * topology the system route can still reach hotspot clients, while binding to an unrelated Wi-Fi
 * STA network makes the same host time out. A resolved target must therefore never fall back to an
 * arbitrary candidate that has no route for that address.
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
}
