# Flutter ProGuard 规则
# 用于代码混淆和优化

## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

## Gson 规则（如果使用）
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

## 保留模型类（根据项目实际情况调整）
-keep class com.xingchuiye.yuezhan.models.** { *; }

## Audio Service
-keep class com.ryanheise.audioservice.** { *; }

## WebView
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, jav.lang.String);
}

## 其他常用规则
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# 如果崩溃，保留行号信息
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# 移除日志（生产环境）
# -assumenosideeffects class android.util.Log {
#     public static *** d(...);
#     public static *** v(...);
#     public static *** i(...);
# }

