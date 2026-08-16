package com.cacl2.ztransfer.camera.transport

import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PtpIpEventTest {
    @Test
    fun `object added payload preserves unsigned transaction and handle`() {
        val payload = ByteBuffer.allocate(10)
            .order(ByteOrder.LITTLE_ENDIAN)
            .putShort(PtpIpConstants.EVT_ObjectAdded.toShort())
            .putInt(0xffff_fffe.toInt())
            .putInt(0x8123_4567.toInt())
            .array()

        val event = PtpIpEventDecoder.decode(payload)

        assertEquals(PtpIpConstants.EVT_ObjectAdded, event?.code)
        assertEquals(0xffff_fffeL, event?.transactionId)
        assertEquals(listOf(0x8123_4567L), event?.parameters)
    }

    @Test
    fun `short event payload is rejected`() {
        assertNull(PtpIpEventDecoder.decode(ByteArray(5)))
    }

    @Test
    fun `object event buffer coalesces duplicate camera notifications`() {
        val buffer = PtpIpObjectEventBuffer()

        assertTrue(buffer.offer(0x1020_3040))
        assertFalse(buffer.offer(0x1020_3040))
        assertTrue(buffer.contains(0x1020_3040))
        assertEquals(0x1020_3040, buffer.poll())
        assertNull(buffer.poll())
    }

    @Test
    fun `advanced transfer can discard its matching queued event`() {
        val buffer = PtpIpObjectEventBuffer()
        buffer.offer(7)
        buffer.offer(8)

        assertTrue(buffer.discard(7))
        assertEquals(8, buffer.poll())
        assertNull(buffer.poll())
    }
}
