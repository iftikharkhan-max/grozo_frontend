import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Release builds must be signed with the Play upload key. Signing a release with
// the debug key is only allowed for local checks: -PallowDebugSigning
// (or env ORG_GRADLE_PROJECT_allowDebugSigning=true); Play rejects such builds.
val allowDebugSigning = project.hasProperty("allowDebugSigning")
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { it.name.contains("Release") }
    if (buildingRelease && !keystorePropertiesFile.exists() && !allowDebugSigning) {
        throw GradleException(
            "android/key.properties is missing, so this release cannot be signed with the " +
                "Google Play upload key. Create it from android/key.properties.example."
        )
    }
}

// App version comes straight from pubspec.yaml ("version: 2.1.0+6" ->
// versionName 2.1.0, versionCode 6). Flutter normally passes it through
// android/local.properties, but that file is only refreshed by `flutter build`;
// building from Android Studio (Build > Generate Signed Bundle) used to pick up
// the previous release's number, which Google Play rejects.
val pubspecVersion: String = rootProject.file("../pubspec.yaml").readLines()
    .first { it.trimStart().startsWith("version:") }
    .substringAfter("version:").trim()
val appVersionName = pubspecVersion.substringBefore("+")
val appVersionCode = pubspecVersion.substringAfter("+", "1").toInt()

android {
    namespace = "com.iftikhar.grozo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Needed by flutter_local_notifications (new-order alerts for staff).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.iftikhar.grozo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = appVersionCode
        versionName = appVersionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
