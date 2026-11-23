import java.io.File

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    // Screens rendered on the JVM (Robolectric) and saved as PNG: see android/README.md, "Captures".
    id("io.github.takahirom.roborazzi")
}

// The iOS app is the single source of the content: images, fonts, texts and translations are
// copied from ../Artura at build time (see the two tasks at the end of this file).
val iosRoot = rootProject.projectDir.parentFile
val generatedRes = layout.buildDirectory.dir("generated/artura/res")
val generatedAssets = layout.buildDirectory.dir("generated/artura/assets")

android {
    namespace = "com.vikstudios.artura"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.vikstudios.artura"
        minSdk = 26
        targetSdk = 35
        // Each upload to Google Play needs a higher number: the release workflow passes its run number.
        versionCode = System.getenv("ANDROID_VERSION_CODE")?.toIntOrNull() ?: 24
        versionName = "2.0"
    }

    signingConfigs {
        // Shared debug key (committed on purpose): every debug build, on any computer or on GitHub,
        // has the same SHA-1, the one declared in the "Android (debug)" OAuth client of Google Cloud.
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        // Upload key for Google Play: never committed. Given by environment variables (GitHub secrets
        // ANDROID_KEYSTORE_B64 → decoded to a file by the release workflow).
        create("release") {
            val path = System.getenv("ANDROID_KEYSTORE_FILE")
            if (path != null) {
                storeFile = file(path)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "artura-upload"
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (System.getenv("ANDROID_KEYSTORE_FILE") != null) signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    sourceSets["main"].res.srcDir(generatedRes)
    sourceSets["main"].assets.srcDir(generatedAssets)
    testOptions {
        unitTests.isIncludeAndroidResources = true
        unitTests.all {
            it.maxHeapSize = "3g"
            it.systemProperty("robolectric.dependency.repo.url", "https://maven-central.storage-download.googleapis.com/maven2")
        }
    }
    androidResources {
        noCompress += listOf("json", "strings")
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.compose.ui:ui-tooling-preview")

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-process:2.8.7")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // Images of the online catalog (memory + disk cache).
    implementation("io.coil-kt:coil-compose:2.7.0")
    // Artura Pro subscription.
    implementation("com.android.billingclient:billing-ktx:7.1.1")
    // Google sign-in (Credential Manager).
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
    // Session of the account, encrypted on the device.
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    // "Artwork of the day" home screen widget.
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")
    implementation("androidx.work:work-runtime-ktx:2.10.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("io.github.takahirom.roborazzi:roborazzi:1.32.2")
    testImplementation("io.github.takahirom.roborazzi:roborazzi-compose:1.32.2")
    testImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}

// MARK: - Content shared with the iOS app

/// Images of Artura/Assets.xcassets → res/drawable-nodpi (same names), fonts → res/font.
val syncIosResources by tasks.registering {
    val xcassets = File(iosRoot, "Artura/Assets.xcassets")
    val fonts = File(iosRoot, "Artura/Fonts")
    inputs.dir(xcassets)
    inputs.dir(fonts)
    outputs.dir(generatedRes)
    doLast {
        val out = generatedRes.get().asFile
        out.deleteRecursively()
        val drawables = File(out, "drawable-nodpi").apply { mkdirs() }
        xcassets.listFiles().orEmpty().filter { it.name.endsWith(".imageset") }.forEach { set ->
            val name = set.name.removeSuffix(".imageset")
            set.listFiles().orEmpty().firstOrNull { it.extension in listOf("png", "jpg", "jpeg") }?.let { image ->
                image.copyTo(File(drawables, "$name.${image.extension.lowercase().replace("jpeg", "jpg")}"), overwrite = true)
            }
        }
        File(xcassets, "AppIcon.appiconset/icon.png").takeIf { it.exists() }
            ?.copyTo(File(drawables, "app_icon.png"), overwrite = true)
        val fontDir = File(out, "font").apply { mkdirs() }
        mapOf(
            "Figtree_400Regular.ttf" to "figtree_regular.ttf",
            "Figtree_500Medium.ttf" to "figtree_medium.ttf",
            "Figtree_600SemiBold.ttf" to "figtree_semibold.ttf",
            "Figtree_700Bold.ttf" to "figtree_bold.ttf",
        ).forEach { (from, to) -> File(fonts, from).copyTo(File(fontDir, to), overwrite = true) }
    }
}

/// Artura/Resources → assets: content*.json, lessons.*.json, palettes.json, and the interface
/// translations (<code>.lproj/Localizable.strings → i18n/<code>.strings).
val syncIosAssets by tasks.registering {
    val resources = File(iosRoot, "Artura/Resources")
    val widget = File(iosRoot, "ArturaWidget")
    inputs.dir(resources)
    inputs.dir(widget)
    outputs.dir(generatedAssets)
    doLast {
        val out = generatedAssets.get().asFile
        out.deleteRecursively()
        out.mkdirs()
        resources.listFiles().orEmpty().filter { it.extension == "json" }.forEach {
            it.copyTo(File(out, it.name), overwrite = true)
        }
        val i18n = File(out, "i18n").apply { mkdirs() }
        resources.listFiles().orEmpty().filter { it.name.endsWith(".lproj") }.forEach { dir ->
            File(dir, "Localizable.strings").takeIf { it.exists() }
                ?.copyTo(File(i18n, dir.name.removeSuffix(".lproj") + ".strings"), overwrite = true)
        }
        val widgetI18n = File(out, "i18n-widget").apply { mkdirs() }
        widget.listFiles().orEmpty().filter { it.name.endsWith(".lproj") }.forEach { dir ->
            File(dir, "Localizable.strings").takeIf { it.exists() }
                ?.copyTo(File(widgetI18n, dir.name.removeSuffix(".lproj") + ".strings"), overwrite = true)
        }
    }
}

tasks.named("preBuild") { dependsOn(syncIosResources, syncIosAssets) }
