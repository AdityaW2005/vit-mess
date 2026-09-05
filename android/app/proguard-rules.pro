# flutter_local_notifications serialises scheduled notifications with Gson, so
# R8 must not rename the classes it reflects over. Without this, reminders are
# lost on reboot in a minified build.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.errorprone.annotations.**

# Gson's own reflective machinery.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
