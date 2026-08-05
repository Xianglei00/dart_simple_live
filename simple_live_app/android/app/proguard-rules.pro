#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class de.prosiebensat1digital.** { *; }
# 录屏插件(含前台服务组件,混淆会导致录屏崩溃)
-keep class com.isvisoft.flutter_screen_recording.** { *; }
-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn io.flutter.embedding.**
-ignorewarnings