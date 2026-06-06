# Gson — R8 full mode'da TypeToken generic imzalarını korur.
# Play Console: TypeToken.getTypeTokenTypeArgument IllegalStateException
-keepattributes Signature

-if class com.google.gson.reflect.TypeToken
-keep,allowobfuscation class com.google.gson.reflect.TypeToken

-keep,allowobfuscation class * extends com.google.gson.reflect.TypeToken

-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
