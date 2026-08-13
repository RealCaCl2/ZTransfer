package com.cacl2.ztransfer.camera.transport

/** Decisions that can be tested without opening Android sockets. */
internal object PtpIpHandshakePolicy {
    /**
     * A newly-created command socket cannot legitimately receive an Event before InitCommandAck.
     * Nikon firmware can briefly attach a rapid reconnect to the previous event session; retrying
     * with a new TCP socket is safer than interpreting that event as the new command handshake.
     */
    fun isStaleSessionPacketBeforeCommandAck(packetType: Int): Boolean =
        packetType == PtpIpConstants.PKT_EVENT
}
