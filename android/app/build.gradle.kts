import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.vynox.attendigo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.vynox.attendigo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }

        // ✅ CORRECT WAY FOR KOTLIN DSL:
        manifestPlaceholders["firebase_messaging_default_notification_channel_id"] = "high_priority"
    }


    dependencies {

        // Firebase BOM
        implementation(platform("com.google.firebase:firebase-bom:32.7.4"))

        // Firebase
        implementation("com.google.firebase:firebase-analytics")
        implementation("com.google.firebase:firebase-messaging-ktx")

        // WorkManager (required for workmanager plugin)
        implementation("androidx.work:work-runtime-ktx:2.9.0")

        implementation("androidx.startup:startup-runtime:1.1.1")


        // AndroidX
        implementation("androidx.core:core-ktx:1.12.0")
        implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

        // Multidex
        implementation("androidx.multidex:multidex:2.0.1")
    }

    signingConfigs {
        create("release") {
            storeFile = file(keyProperties["storeFile"].toString())
            storePassword = keyProperties["storePassword"].toString()
            keyAlias = keyProperties["keyAlias"].toString()
            keyPassword = keyProperties["keyPassword"].toString()
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}
