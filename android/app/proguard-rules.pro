# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google ML Kit Text Recognition generic avoid missing classes warning
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.** { *; }

# Play Core library (used by Flutter dynamic features)
-dontwarn com.google.android.play.core.**
