package com.kw.ztransfer;

import android.util.Log;

/**
 * JNI bridge for the ZTransfer native PTP core.
 *
 * <p>The native library registers methods by the exact class name, method name and descriptor.
 * The private n01-n17 declarations therefore intentionally mirror the obfuscated declarations in
 * The packaged native library expects these exact declarations. Keep these names and signatures
 * unchanged. The descriptive public methods isolate
 * the rest of ZTransfer from those ABI names.</p>
 */
public final class NativePtpCore implements AutoCloseable {
    private static final String TAG = "NativePtpCore";
    public static final boolean isLoaded;

    static {
        boolean loaded = false;
        try {
            System.loadLibrary("ztransfer_core");
            loaded = true;
            Log.i(TAG, "ZTransfer native PTP core loaded");
        } catch (UnsatisfiedLinkError error) {
            Log.e(TAG, "Native core load failed", error);
        }
        isLoaded = loaded;
    }

    private long pointer;

    private native long n01();
    private native void n02(long pointer);
    private native byte[] n03(long pointer, byte[] guid, String initiatorName);
    private native byte[] n04(long pointer, long connectionNumber);
    private native void n05(long pointer);
    private native void n06(long pointer);
    private native void n07(long pointer);
    private native void n08(long pointer);
    private native void n09(long pointer, boolean enabled);
    private native boolean n10(long pointer);
    private native boolean n11(long pointer);
    private native long n12(long pointer);
    private native void n13(long pointer, int opcode);
    private native void n14(
            long pointer,
            int[] disabledOperationIds,
            boolean allowApplicationMode,
            boolean allowAdvancedTransfer);
    private native int n15(int operationId);
    private native int n16(int groupId, int valueId);
    private native String n17(int groupId, int value);

    public NativePtpCore() {
        if (!isLoaded) {
            throw new IllegalStateException("libztransfer_core is not loaded");
        }
        pointer = n01();
        if (pointer == 0L) {
            throw new IllegalStateException("native PTP core initialization failed");
        }
    }

    private long requirePointer() {
        if (pointer == 0L) {
            throw new IllegalStateException("native PTP core is closed");
        }
        return pointer;
    }

    public byte[] buildInitCommandPayload(byte[] guid, String initiatorName) {
        return n03(requirePointer(), guid, initiatorName);
    }

    public byte[] buildInitEventPayload(long connectionNumber) {
        return n04(requirePointer(), connectionNumber);
    }

    public void onCommandAccepted() {
        n05(requirePointer());
    }

    public void onEventAccepted() {
        n06(requirePointer());
    }

    public void onSessionOpened() {
        n07(requirePointer());
    }

    public void onSessionClosed() {
        n08(requirePointer());
    }

    public void setApplicationMode(boolean enabled) {
        n09(requirePointer(), enabled);
    }

    public boolean isSessionOpen() {
        return n10(requirePointer());
    }

    public boolean isApplicationModeEnabled() {
        return n11(requirePointer());
    }

    public long nextTransactionId() {
        return n12(requirePointer());
    }

    public void beforeOperation(int opcode) {
        n13(requirePointer(), opcode);
    }

    public void applyRules(
            int[] disabledOperationIds,
            boolean allowApplicationMode,
            boolean allowAdvancedTransfer) {
        n14(
                requirePointer(),
                disabledOperationIds,
                allowApplicationMode,
                allowAdvancedTransfer);
    }

    public int privateOpcode(int operationId) {
        return n15(operationId);
    }

    public int privateValue(int groupId, int valueId) {
        return n16(groupId, valueId);
    }

    public String privateName(int groupId, int value) {
        return n17(groupId, value);
    }

    @Override
    public void close() {
        long current = pointer;
        if (current != 0L) {
            pointer = 0L;
            n02(current);
        }
    }
}
