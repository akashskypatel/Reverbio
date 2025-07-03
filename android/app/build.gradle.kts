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
        //minSdk = flutter.minSdkVersion
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        splits.abi.isEnable = false
        splits.density.isEnable = false
        splits.language.isEnable = false
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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

dependencies {
    implementation("com.github.fast-development.android-js-runtimes:fastdev-jsruntimes-jsc:0.3.5")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.android.play:core:1.10.3")
    implementation("com.google.android.play:core-ktx:1.8.1")
}