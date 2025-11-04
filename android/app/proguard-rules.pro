# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep MLC.ai native library
-keep class ai.mlc.** { *; }
-keepclassmembers class ai.mlc.** { *; }

# Keep Drift/SQLite classes
-keep class com.simolus.** { *; }
-keep class org.sqlite.** { *; }

# Keep flutter_sound
-keep class com.dooboolab.** { *; }

# Standard Flutter rules
-dontwarn com.dooboolab.**
-dontwarn org.sqlite.**
