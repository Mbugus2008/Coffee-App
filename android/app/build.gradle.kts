plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ──────────────────────────────────────────────
// Signing configuration
// Supports:
//   1. LOCAL:   android/key.properties file
//   2. CI/CD:   Environment variables (GitHub Secrets)
// ──────────────────────────────────────────────
import java.util.Properties
import java.io.File

fun loadSigningConfig(): Map<String, String>? {
    // 1. Try local key.properties first
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) {
        val props = Properties()
        keyPropsFile.inputStream().use { stream ->
            props.load(stream)
        }
        val storeFile = props.getProperty("storeFile")?.let {
            rootProject.file(it).absolutePath
        }
        if (storeFile != null && File(storeFile).exists()) {
            return mapOf(
                "storeFile" to storeFile,
                "storePassword" to props.getProperty("storePassword", ""),
                "keyAlias" to props.getProperty("keyAlias", ""),
                "keyPassword" to props.getProperty("keyPassword", "")
            )
        }
    }

    // 2. Fall back to CI environment variables
    val storeFile = System.getenv("ANDROID_KEYSTORE_PATH")
    val storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
    val keyAlias = System.getenv("ANDROID_KEY_ALIAS")
    val keyPassword = System.getenv("ANDROID_KEY_PASSWORD")

    if (!storeFile.isNullOrBlank() && File(storeFile).exists()) {
        return mapOf(
            "storeFile" to storeFile,
            "storePassword" to (storePassword ?: ""),
            "keyAlias" to (keyAlias ?: ""),
            "keyPassword" to (keyPassword ?: "")
        )
    }

    return null
}

android {
    namespace = "com.trimline.coffee"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            val config = loadSigningConfig()
            if (config != null) {
                storeFile = File(config["storeFile"]!!)
                storePassword = config["storePassword"]
                keyAlias = config["keyAlias"]
                keyPassword = config["keyPassword"]
            }
        }
    }

    defaultConfig {
        applicationId = "com.trimline.coffee"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.findByName("release")
            if (releaseSigning != null &&
                releaseSigning.storeFile != null &&
                releaseSigning.storeFile!!.exists()
            ) {
                signingConfig = releaseSigning
            } else {
                // Fall back to debug signing (for dev builds)
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
