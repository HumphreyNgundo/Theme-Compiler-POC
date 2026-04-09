# Keep BuildConfig fields for all flavors
-keepclassmembers class **.BuildConfig {
    public static final java.lang.String CLIENT_ID;
}

# Keep the BuildConfig class itself
-keep class **.BuildConfig {
    public static final java.lang.String CLIENT_ID;
}

# Additional safety for reflection-based access
-keepclassmembers class * {
    public static final java.lang.String CLIENT_ID;
}
