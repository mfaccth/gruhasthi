# LiteRT-LM's native layer looks up these JVM methods through JNI. Their names
# must remain intact in the optimised Android release build.
-keep class com.google.ai.edge.litertlm.** { *; }

# Google Places discovers internal providers at runtime through reflection.
# Retain the SDK classes and constructors in the optimised release build.
-keep class com.google.android.libraries.places.** { *; }
