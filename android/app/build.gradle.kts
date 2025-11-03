import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("kotlin-parcelize")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.akashskypatel.reverbio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        manifestPlaceholders += mapOf(
            "carTemplateEnabled" to "true",
            "appAuthRedirectScheme" to "com.akashskypatel.reverbio"
        )
        applicationId = "com.akashskypatel.reverbio"
        minSdk = flutter.minSdkVersion // flutter.minSdkVersion
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
    
    packaging {
        jniLibs {
            useLegacyPackaging = true
            pickFirsts.add("lib/arm64-v8a/libc++_shared.so")
            pickFirsts.add("lib/armeabi-v7a/libc++_shared.so")
            pickFirsts.add("lib/x86/libc++_shared.so")
            pickFirsts.add("lib/x86_64/libc++_shared.so")
        }
    }

    applicationVariants.all {
        outputs.all {
            val outputImpl = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val appName = "reverbio"
            val versionNameStr = versionName
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
    implementation("androidx.car.app:app:1.2.0")
    implementation("androidx.media:media:1.6.0")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("com.google.android.gms:play-services-base:18.2.0")
    implementation("com.github.fast-development.android-js-runtimes:fastdev-jsruntimes-jsc:0.3.5")
    implementation("androidx.annotation:annotation:1.7.1")
}
