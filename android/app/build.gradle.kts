import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing credentials from key.properties when available (keystore stays out of VCS)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(keystorePropertiesFile.inputStream())
    }
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.rhythora.player"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Explicitly set Kotlin JVM target to 17 
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Use the Play Store package id consistently (matches AndroidManifest and rate link)
        applicationId = "com.rhythora.player"

        minSdk = flutter.minSdkVersion
        targetSdk = 35

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use release keystore when provided, otherwise fall back to debug for local builds
            signingConfig =
                if (hasReleaseKeystore) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")

            // Enable shrinking/obfuscation for Play builds
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Modern Play Feature Delivery library (provides SplitInstall APIs) compatible with target/compile SDK 35+
    implementation("com.google.android.play:feature-delivery:2.1.0")
    // Core task APIs used by Play Feature Delivery (OnSuccessListener/OnFailureListener/Task)
    implementation("com.google.android.play:core-common:2.0.4")
}
