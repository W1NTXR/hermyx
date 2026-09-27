plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Bridgefy's Android SDK reads the API key from AndroidManifest meta-data as well as from
// initialize(), so pull it from the same env.json used for --dart-define-from-file.
val bridgefyApiKey: String = run {
    val envFile = rootProject.file("../env.json")
    if (!envFile.exists()) return@run ""
    val match = Regex("\"BRIDGEFY_API_KEY\"\\s*:\\s*\"([^\"]*)\"").find(envFile.readText())
    match?.groupValues?.get(1) ?: ""
}

android {
    namespace = "com.w1ntxr.hermyx"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // The Bridgefy SDK requires this.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        // Two Bridgefy dependencies (okhttp, jspecify) ship this same metadata file.
        resources.excludes += "META-INF/versions/9/OSGI-INF/MANIFEST.MF"
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.w1ntxr.hermyx"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["bridgefyApiKey"] = bridgefyApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
