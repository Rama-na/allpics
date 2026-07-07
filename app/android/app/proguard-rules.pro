# Razorpay SDK keep rules (required for release builds with R8).
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-optimizations !method/inlining/*
-keepclasseswithmembers class * { public void onPayment*(...); }

# Flutter deferred components / Play Core are not used.
-dontwarn com.google.android.play.core.**
