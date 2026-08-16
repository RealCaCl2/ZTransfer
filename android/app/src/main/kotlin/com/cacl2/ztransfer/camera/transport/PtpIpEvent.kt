package com.cacl2.ztransfer.camera.transport

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.LinkedHashSet

/** Decoded payload of a PTP/IP Event packet (packet type 8). */
internal data class PtpIpEvent(
    val code: Int,
    val transactionId: Long,
    val parameters: List<Long>,
)

/**
 * Decodes the payload after the common PTP/IP packet header.
 *
 * Event payloads contain a 16-bit event code, a 32-bit transaction id, and
 * zero or more 32-bit parameters. Nikon uses the first ObjectAdded parameter
 * as the object handle selected for upload.
 */
internal object PtpIpEventDecoder {
    fun decode(payload: ByteArray): PtpIpEvent? {
        if (payload.size < MIN_PAYLOAD_BYTES) return null

        val buffer = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN)
        val code = buffer.short.toInt() and 0xffff
        val transactionId = buffer.int.toLong() and UINT32_MASK
        val parameters = buildList {
            while (buffer.remaining() >= Int.SIZE_BYTES) {
                add(buffer.int.toLong() and UINT32_MASK)
            }
        }
        return PtpIpEvent(code, transactionId, parameters)
    }

    private const val MIN_PAYLOAD_BYTES = Short.SIZE_BYTES + Int.SIZE_BYTES
    private const val UINT32_MASK = 0xffff_ffffL
}

/**
 * Thread-safe, insertion-ordered set of object handles received on the event socket.
 *
 * A Nikon body can report the same upload through both ObjectAdded and the
 * AdvancedTransfer response. Coalescing by handle prevents a second download.
 */
internal class PtpIpObjectEventBuffer {
    private val pending = LinkedHashSet<Int>()

    @Synchronized
    fun offer(handle: Int): Boolean = handle != 0 && pending.add(handle)

    @Synchronized
    fun poll(): Int? {
        val iterator = pending.iterator()
        if (!iterator.hasNext()) return null
        return iterator.next().also { iterator.remove() }
    }

    @Synchronized
    fun contains(handle: Int): Boolean = handle in pending

    @Synchronized
    fun discard(handle: Int): Boolean = pending.remove(handle)

    @Synchronized
    fun clear() = pending.clear()
}
