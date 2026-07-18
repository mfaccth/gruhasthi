# LiteRT-LM's native layer looks up these JVM methods through JNI. Their names
# must remain intact in the optimised Android release build.
-keep class com.google.ai.edge.litertlm.** { *; }
