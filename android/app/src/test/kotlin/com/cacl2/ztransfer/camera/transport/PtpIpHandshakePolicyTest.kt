package com.cacl2.ztransfer.camera.transport

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PtpIpHandshakePolicyTest {
    @Test
    fun `event before command ack belongs to a stale session`() {
        assertTrue(
            PtpIpHandshakePolicy.isStaleSessionPacketBeforeCommandAck(
                PtpIpConstants.PKT_EVENT,
            ),
        )
    }

    @Test
    fun `command ack is not treated as stale session traffic`() {
        assertFalse(
            PtpIpHandshakePolicy.isStaleSessionPacketBeforeCommandAck(
                PtpIpConstants.PKT_INIT_CMD_ACK,
            ),
        )
    }

    @Test
    fun `init failure remains an authoritative camera response`() {
        assertFalse(
            PtpIpHandshakePolicy.isStaleSessionPacketBeforeCommandAck(
                PtpIpConstants.PKT_INIT_FAIL,
            ),
        )
    }
}
