import com.android.build.gradle.internal.api.BaseVariantOutputImpl
import java.util.Properties
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
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

    splits {
      abi {
        isEnable = true
        reset()
        include("armeabi-v7a", "arm64-v8a", "x86_64")
        isUniversalApk = true
      }
    }

    buildTypes {
        release {
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
            val abi = outputImpl.filters.find { it.filterType == "ABI" }?.identifier
                ?: if (outputImpl.filters.isEmpty()) "universal" else "multi"
            outputImpl.outputFileName =
                "${appName}_${versionNameStr}_${abi}_android.apk"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.github.fast-development.android-js-runtimes:fastdev-jsruntimes-jsc:0.3.5")
}