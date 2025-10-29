// android/build.gradle.kts  (root)

buildscript {
    repositories {
        google()
        mavenCentral()
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Imposta la directory di build root e per i subprojects (tipo :app)
rootProject.buildDir = File(rootDir, "../build")

subprojects {
    buildDir = File(rootProject.buildDir, name)
}

// Task clean in Kotlin DSL
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
