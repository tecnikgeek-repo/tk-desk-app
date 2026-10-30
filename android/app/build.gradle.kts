plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "it.pietrodefilippis.tkdesk"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "it.pietrodefilippis.tkdesk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // chiave fissa di tk-desk, FUORI dal repo: in CI arriva dal segreto ANDROID_KEYSTORE_B64 (percorso nella
    // variabile ANDROID_KEYSTORE). La firma non cambia tra una versione e l'altra, così gli aggiornamenti si
    // installano sopra. Senza la variabile (rami senza segreto, chi compila dal sorgente) = chiave di debug di Flutter.
    val chiaveTk = System.getenv("ANDROID_KEYSTORE")?.takeIf { it.isNotBlank() && file(it).exists() }
    signingConfigs {
        if (chiaveTk != null) {
            create("tk") {
                storeFile = file(chiaveTk)
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
    }

    // versione per il Play Store (play.yml, TK_PLAY=1): il manifest di src/play toglie il permesso di installare APK.
    // Stesso pacchetto e stessa chiave: chi ha l'app da Dropbox si aggiorna da Play senza disinstallare.
    if (System.getenv("TK_PLAY") == "1") {
        sourceSets.getByName("release").manifest.srcFile("src/play/AndroidManifest.xml")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("tk") ?: signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
