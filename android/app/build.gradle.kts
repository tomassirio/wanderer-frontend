import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing key properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// Load Google Maps API key from local.properties or .env
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

// Try local.properties first, then fall back to .env file, then --dart-define
var googleMapsApiKey = localProperties.getProperty("GOOGLE_MAPS_API_KEY", "")
if (googleMapsApiKey.isBlank()) {
    val envFile = rootProject.file("../.env")
    if (envFile.exists()) {
        envFile.readLines().forEach { line ->
            if (line.startsWith("GOOGLE_MAPS_API_KEY=")) {
                googleMapsApiKey = line.substringAfter("=").trim()
            }
        }
    }
}

// Fall back to --dart-define values (Flutter passes these as base64-encoded project property)
if (googleMapsApiKey.isBlank()) {
    val dartDefines = project.properties["dart-defines"] as String?
    dartDefines?.split(",")?.forEach { encoded ->
        try {
            val decoded = String(Base64.getDecoder().decode(encoded))
            if (decoded.startsWith("GOOGLE_MAPS_API_KEY=")) {
                googleMapsApiKey = decoded.substringAfter("=").trim()
            }
        } catch (_: Exception) {
            // Ignore malformed entries
        }
    }
}

android {
    namespace = "com.tomassirio.wanderer.wanderer_frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tomassirio.wanderer.wanderer_frontend"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Inject the Google Maps API key into AndroidManifest.xml
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        if (keystoreProperties.containsKey("keyAlias") &&
            keystoreProperties.containsKey("keyPassword") &&
            keystoreProperties.containsKey("storeFile") &&
            keystoreProperties.containsKey("storePassword")) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.names.contains("release")) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // AndroidX Activity 1.10+ handles edge-to-edge on API 35+ without
    // calling the deprecated setStatusBarColor / setNavigationBarColor APIs.
    implementation("androidx.activity:activity-ktx:1.10.0")
}

