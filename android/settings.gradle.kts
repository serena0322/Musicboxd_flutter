pluginManagement {
    val flutterSdk = run {
        val p = java.util.Properties()
        file("local.properties").inputStream().use { p.load(it) }
        requireNotNull(p.getProperty("flutter.sdk")) { "flutter.sdk not set in local.properties" }
    }

    includeBuild("$flutterSdk/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // Forza qualsiasi plugin Kotlin a 1.9.22
    plugins {
        id("org.jetbrains.kotlin.android") version "2.1.0"
        id("org.jetbrains.kotlin.jvm") version "2.1.0"
        id("org.jetbrains.kotlin.kapt") version "2.1.0"
    }
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id.startsWith("org.jetbrains.kotlin")) {
                useVersion("2.1.0")
            }
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id ("com.google.gms.google-services") version "4.4.2" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
