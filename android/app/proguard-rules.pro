# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keep,includedescriptorclasses class com.vikstudios.artura.**$$serializer { *; }
-keepclassmembers class com.vikstudios.artura.** {
    *** Companion;
}
-keepclasseswithmembers class com.vikstudios.artura.** {
    kotlinx.serialization.KSerializer serializer(...);
}
