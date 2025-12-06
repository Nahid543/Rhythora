# Flutter/Just Audio/AudioService keep rules

# Keep Flutter embedding classes
-keep class io.flutter.embedding.engine.** { *; }

# Keep generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Audio service/media session classes used by just_audio_background
-keep class com.ryanheise.audioservice.** { *; }
-keep class androidx.media.** { *; }

# Ignore optional Play Core task/splitinstall classes used only by deferred components stubs
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.splitinstall.**

# on_audio_query models/reflection
-keep class com.lucasjosino.on_audio_query.** { *; }

# Keep Kotlin metadata for reflection
-keepclassmembers class **$Companion { *; }
-keepclassmembers class kotlin.Metadata { *; }

# Retrofit/okhttp not used; leave defaults otherwise
