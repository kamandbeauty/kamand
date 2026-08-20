# ---------------------------------------------------------------------------
# MEMORY — R8 / ProGuard rules for the release build.
#
# The release build has minification AND resource shrinking enabled, so every
# type that is looked up reflectively (rather than called directly) must be
# kept explicitly. Getting this wrong produces a build that installs fine but
# crashes at runtime — which is exactly what happened before these rules
# existed: Room resolves its generated implementation by name
# ("MemoryDatabase_Impl"), R8 removed it, and the app died the moment the first
# screen touched the database.
# ---------------------------------------------------------------------------

-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod, RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations

# --- Room -------------------------------------------------------------------
# The generated *_Impl classes are instantiated via Class.forName().
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class com.studiojavid.memory.data.local.**_Impl { *; }
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }
-keep @androidx.room.Database class * { *; }
-dontwarn androidx.room.paging.**

# Entities are also constructed reflectively by the generated adapters, so
# their constructors and fields must survive.
-keepclassmembers class com.studiojavid.memory.data.local.** {
    <init>(...);
    <fields>;
}

# --- Domain / backup models -------------------------------------------------
# Backup JSON is written and parsed by name.
-keep class com.studiojavid.memory.data.backup.** { *; }
-keep class com.studiojavid.memory.data.repo.** { *; }

# --- Enums ------------------------------------------------------------------
# valueOf()/values() are used when restoring persisted settings and rules.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- WorkManager ------------------------------------------------------------
# Workers are instantiated by name from the WorkManager registry.
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class com.studiojavid.memory.notifications.RescheduleWorker { *; }

# --- Manifest components ----------------------------------------------------
# Receivers/services are created reflectively by the framework.
-keep class com.studiojavid.memory.widget.** { *; }
-keep class com.studiojavid.memory.notifications.** { *; }
-keep class * extends android.app.Application { *; }
-keep class * extends android.content.BroadcastReceiver { *; }
-keep class * extends android.app.Service { *; }

# --- DataStore --------------------------------------------------------------
-keep class androidx.datastore.*.** { *; }

# --- Kotlin / coroutines ----------------------------------------------------
-dontwarn org.jetbrains.annotations.**
-dontwarn kotlinx.coroutines.**
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }

# --- Keep line numbers so a production stack trace is readable --------------
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
