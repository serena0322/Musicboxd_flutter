import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")      // Kotlin Android
    id("dev.flutter.flutter-gradle-plugin") // Deve venire dopo Android e Kotlin
    id("com.google.gms.google-services")
}

// Carica le credenziali dal file android/key.properties (non committare)
val keystoreProperties = Properties().apply {
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) {
        load(FileInputStream(keystoreFile))
    }
}

android {
    // Usare il namespace del package (coerente con ApplicationId)
    namespace = "com.example.musicboxd_flutter"

    // Valori forniti dal Flutter Gradle plugin
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.musicboxd_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // Java/Kotlin 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    // Firma RELEASE (usa key.properties). Se il file manca, Gradle fallirà con errore esplicito.
    signingConfigs {
        create("release") {
            // Evita NPE se il file non esiste
            val store = keystoreProperties["storeFile"] as String?
            if (store != null) {
                storeFile = file(store)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        // Debug invariato
        getByName("debug") {
            // niente di speciale
        }
        // Release firmata; parta senza shrink/obfuscation per validare l’APK
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // (Opzionale) genera APK universale; in alternativa usi --split-per-abi da CLI
    // androidResources { noCompress += setOf() }
}

kotlin {
    jvmToolchain(17)
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
