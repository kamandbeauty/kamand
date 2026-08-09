# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class ir.factoryar.core.domain.model.** {
    *** serializer();
}
-keep,includedescriptorclasses class ir.factoryar.core.domain.model.**$$serializer { *; }

# Room
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.paging.**

# SQLCipher
-keep class net.sqlcipher.** { *; }

# Poolakey / Bazaar
-keep class ir.cafebazaar.poolakey.** { *; }
