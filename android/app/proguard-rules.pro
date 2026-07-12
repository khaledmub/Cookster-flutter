# Flutter deferred components (Play Core — optional at runtime)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Suppress warnings for SSL and security libraries
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE

# Video player and ExoPlayer rules
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn androidx.media3.**
-dontwarn com.google.android.exoplayer2.**

# Keep video player related classes
-keep class * implements androidx.media3.common.Player { *; }
-keep class * implements androidx.media3.exoplayer.source.MediaSource { *; }

# Keep MediaCodec related classes
-keep class androidx.media3.exoplayer.mediacodec.** { *; }
-keep class androidx.media3.exoplayer.video.** { *; }
-keep class androidx.media3.exoplayer.audio.** { *; }

# Flutter video player specific
-keep class io.flutter.plugins.videoplayer.** { *; }
-dontwarn io.flutter.plugins.videoplayer.**

# MediaKit / libmpv (reels use this — required for release APK video surfaces)
-keep class com.alexmercerind.** { *; }
-keep class com.alexmercerind.media_kit_video.** { *; }
-keep class com.alexmercerind.media_kit_libs_android_video.** { *; }
-keep class com.alexmercerind.mediakitandroidhelper.** { *; }
-dontwarn com.alexmercerind.**

# Network images (CachedNetworkImage / http)
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class com.davemorrissey.labs.subscaleview.** { *; }

# Flutter embedding + plugins (JNI / platform views)
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }

# Google Sign-In + Firebase Auth (required for release APK login)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**
-keep class io.flutter.plugins.googlesignin.** { *; }
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Additional media format support
-keep class androidx.media3.extractor.** { *; }
-keep class androidx.media3.decoder.** { *; }
-dontwarn androidx.media3.extractor.**
-dontwarn androidx.media3.decoder.**

# FFmpegKit - prevent R8/ProGuard from stripping JNI native classes
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class com.antonkarpenko.ffmpegkit.AbiDetect { *; }
-keep class com.antonkarpenko.ffmpegkit.FFmpegKitConfig { *; }

# MediaKit native event loop — R8 optimize inlines JNI callbacks that
# media_kit_video expects to invoke reflectively for surface recovery.
-keepclassmembers class com.alexmercerind.media_kit_video.** {
    native <methods>;
    void surfaceTextureAvailable(...);
    void surfaceTextureDestroyed(...);
    void surfaceTextureUpdated(...);
}
-keep class com.alexmercerind.media_kit_video.VideoOutput { *; }
-keep class com.alexmercerind.media_kit_video.VideoOutputManager { *; }
# Keep the native event loop that drives mpv → Flutter texture binding.
-keep class com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper {
    *;
}