# ---------------------------------------------------------
# REGLAS PARA GOOGLE ML KIT (Reconocimiento de Texto)
# ---------------------------------------------------------
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google_mlkit_text_recognition.**

# ---------------------------------------------------------
# REGLAS PARA PLAY CORE (Errores de Deferred Components)
# ---------------------------------------------------------
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-dontwarn com.google.android.play.core.**

# ---------------------------------------------------------
# REGLAS BASE DE FLUTTER
# ---------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ---------------------------------------------------------
# REGLAS PARA SQLITE (Sqflite)
# ---------------------------------------------------------
-keep class com.tekartik.sqflite.** { *; }