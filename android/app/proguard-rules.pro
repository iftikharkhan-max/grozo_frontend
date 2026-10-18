# R8 rules for Grozo (release builds are shrunk and obfuscated).
# Flutter and the plugins add their own rules; these cover the rest.

# Flutter refers to Play Core (deferred components), which this app doesn't use.
-dontwarn com.google.android.play.core.**

# Native code called by name from Dart (grozo/config channel).
-keep class com.iftikhar.grozo.MainActivity { *; }

# Keep line numbers so crash reports can be read (Play uses the mapping file).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
