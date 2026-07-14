plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ruolan.ruolan_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ruolan.ruolan_app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            ndk {
                abiFilters += "arm64-v8a"
            }
        }
        debug {
            ndk {
                abiFilters += "arm64-v8a"
            }
        }
    }
    // 说明：预编译的 .so（含 libllama_wrapper.so）位于默认目录 src/main/jniLibs，
    // 无需显式配置 sourceSets。C++ 改动需通过独立 NDK 编译产出 .so（见 scripts/check_native_cpp.sh）。
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

flutter { source = "../.." }
