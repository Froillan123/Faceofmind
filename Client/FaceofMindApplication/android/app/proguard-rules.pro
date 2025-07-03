# Prevent R8 from removing ML Kit classes
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# For Text Recognition (English, Chinese, Japanese, etc.)
-keep class com.google.mlkit.vision.text.** { *; }

# Prevent removal of classes used with reflection
-keepattributes Signature
-keepattributes *Annotation*

# For Flutter + Firebase / MLKit compatibility
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Play Core classes for Flutter deferred components (fixes R8 errors)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep TensorFlow Lite GPU delegate classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate$Options { *; }

# Keep all TensorFlow Lite classes (including GPU delegate)
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate$Options { *; } 