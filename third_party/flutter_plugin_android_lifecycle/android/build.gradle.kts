group = "io.flutter.plugins.flutter_plugin_android_lifecycle"
version = "1.0"

// 仓库统一由根工程的 settings.gradle.kts(dependencyResolutionManagement)管理,
// 此处不再声明项目级仓库,否则会覆盖 settings 的镜像配置导致依赖解析失败。

plugins {
    id("com.android.library")
}

android {
    namespace = "io.flutter.plugins.flutter_plugin_android_lifecycle"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        minSdk = 24
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("proguard.txt")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    lint {
        checkAllWarnings = true
        warningsAsErrors = true
        disable.addAll(setOf("AndroidGradlePluginVersion", "InvalidPackage", "GradleDependency", "NewerVersionAvailable"))
    }

    dependencies {
        implementation("androidx.annotation:annotation:1.10.0")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            isReturnDefaultValues = true
            all {
                it.outputs.upToDateWhen { false }
                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.23.0")
}
