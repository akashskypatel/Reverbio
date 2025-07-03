import com.android.build.gradle.internal.api.BaseVariantOutputImpl
import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.akashskypatel.reverbio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.akashskypatel.reverbio"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            //signingConfig = signingConfigs.getByName("debug")
            signingConfig = signingConfigs.create("release") {
              val props = Properties()
              props.load(File(rootDir, "key.properties").inputStream())

              storeFile = file(props["storeFile"] as String)
              storePassword = props["storePassword"] as String
              keyAlias = props["keyAlias"] as String
              keyPassword = props["keyPassword"] as String
          }
        }
    }
    applicationVariants.all {
        outputs.all {
            val outputImpl = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val appName = "reverbio"
            val buildType = name
            val versionNameStr = versionName
            val versionCodeInt = versionCode

            outputImpl.outputFileName =
                "${appName}_${versionNameStr}_android.apk"
        }
    }
}

flutter {
    source = "../.."
}
