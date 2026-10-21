# Плагины, которые Dart вызывает напрямую через JNI: R8 не видит этих вызовов
# и вырезает классы из релизной сборки.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.** { *; }
