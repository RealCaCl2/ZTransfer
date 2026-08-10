# Flutter — keep all FFI / platform channel method signatures
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep Kotlin coroutine internals (used by UpdateChannelHandler, PtpManager)
-keepnames class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Keep USB / MTP classes (reflectively accessed)
-keep class android.hardware.usb.** { *; }
-keep class android.mtp.** { *; }

# Keep FileProvider
-keep class androidx.core.content.FileProvider { *; }

# Keep app's own channel handlers (MethodChannel calls by string name)
-keep class com.cacl2.ztransfer.** { *; }

# Keep the ZTransfer native JNI bridge (RegisterNatives in libztransfer_core.so targets this class)
-keep class com.kw.ztransfer.** { *; }
-keepclasseswithmembernames,includedescriptorclasses class com.kw.ztransfer.** {
    native <methods>;
}
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep data classes used in JSON serialization
-keepclassmembers class * {
    <init>(...);
}
