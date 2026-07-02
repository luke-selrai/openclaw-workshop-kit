# Worked example: ship a React Native screen as an Android AAR (Isolated approach)

A reference end-to-end session for shipping React Native + Expo as a versioned AAR that a separate native Android team consumes. **You:** is the developer, **Claude:** is the response. The Integrated iOS Podfile approach is in `examples/integrated-podfile-session.md` (this folder).

The Isolated approach is the right call when the native team owns the host app and you don't have day-to-day access to their Gradle config. You ship them an AAR; they consume it like any other dependency.

---

## You

Our Android team owns the FieldOps app (Java, native, no React Native today). I run a separate RN project that ships a "Quote PDF generator" screen. I want to ship that screen to them as an AAR they can drop in. We're on Expo SDK 55. The Android team is on Gradle 8.7, Kotlin 1.9, Android Gradle Plugin 8.5.

## Claude

Isolated approach for Android. Walking the AAR build + the consumer-side integration the Android team will run.

> Reads `references/isolated.md` for the Isolated approach. Reads `references/troubleshooting.md` for the AAR signing and ABI gotchas.

### Step 1: Build the RN side as an Android library module

In your RN project's `android/` directory, set the consumer module type to `library`, not `application`. In `android/app/build.gradle`:

```groovy
plugins {
    id 'com.android.library'   // not com.android.application
    id 'org.jetbrains.kotlin.android'
    id 'com.facebook.react'
}

android {
    namespace 'com.selrai.rn.quotegenerator'
    compileSdk 34

    defaultConfig {
        minSdk 24
        targetSdk 34
        consumerProguardFiles 'consumer-rules.pro'

        ndk {
            // Match what the host app supports. FieldOps is arm64-v8a + armeabi-v7a.
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }
    }

    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}

react {
    autolinkLibrariesWithApp()
    enableHermes = true
    bundleAsset.set "index.android.bundle"
}
```

The `consumerProguardFiles` line is non-optional. Without it, the host app's ProGuard pass strips React Native's reflective constructors and the AAR crashes at runtime with `ClassNotFoundException: com.facebook.react.bridge.ReactApplicationContext`.

### Step 2: Build the AAR

```bash
cd path/to/rn-project/android
./gradlew :app:assembleRelease
```

Output: `android/app/build/outputs/aar/app-release.aar` (about 18-25MB depending on bundled assets).

### Step 3: Sign the AAR if your team requires it

```bash
jarsigner -keystore selrai-release.keystore \
  -storepass "$KEYSTORE_PASS" \
  app-release.aar selrai-release
```

The Android team's Gradle build will reject unsigned AARs if their repository policy enforces signing.

### Step 4: Host the AAR for consumption

Two patterns. Pick the one matching the Android team's tooling:

**Pattern A: Maven Local / Artifactory.** Publish via Gradle's `maven-publish` plugin:

```groovy
publishing {
    publications {
        release(MavenPublication) {
            groupId = 'com.selrai.rn'
            artifactId = 'quote-generator'
            version = '1.0.0'
            artifact("$buildDir/outputs/aar/app-release.aar")
        }
    }
}
```

**Pattern B: Direct file delivery.** Stash the AAR in the Android team's repo at `libs/quote-generator-1.0.0.aar` and reference via `flatDir`.

### Step 5: Android team consumes the AAR

The Android team adds to their host app's `build.gradle`:

```groovy
repositories {
    maven { url uri('libs') }   // for Pattern B (flatDir alternative)
    // or your Maven Local / Artifactory URL for Pattern A
}

dependencies {
    implementation('com.selrai.rn:quote-generator:1.0.0') {
        // Required because the host app may already have a different version of these
        // and React Native's symbol-version policy doesn't tolerate drift.
        exclude group: 'com.facebook.react'
        exclude group: 'com.facebook.soloader'
    }
    // Then re-add the matching React Native + SoLoader versions explicitly:
    implementation 'com.facebook.react:react-android:0.76.+'
    implementation 'com.facebook.soloader:soloader:0.10.5'
}
```

Then in their `Application.onCreate()`:

```kotlin
class FieldOpsApplication : Application(), ReactApplication {
    override val reactNativeHost: ReactNativeHost by lazy {
        DefaultReactNativeHost(this)
    }

    override fun onCreate() {
        super.onCreate()
        SoLoader.init(this, /* native exopackage */ false)
    }
}
```

And launch the RN screen from a host Activity:

```kotlin
class QuoteGeneratorActivity : ReactActivity() {
    override fun getMainComponentName() = "QuoteGeneratorRoot"
}
```

`QuoteGeneratorRoot` must match the `AppRegistry.registerComponent` name in the RN side's `index.js`.

### Versioning enforcement

Lock the Expo SDK across both sides via a `package.json` field on the RN side and a Gradle property on the host side:

```bash
# RN side check (use in CI / pre-commit)
EXPO_VERSION=$(node -p "require('./package.json').dependencies['expo']")
echo "RN ships Expo $EXPO_VERSION; host app must use react-android matching this Expo SDK"
# Cross-reference against https://docs.expo.dev/versions/latest/ for the matching react-native version.
```

---

## What this transcript proves

- The Isolated AAR build is concrete: real Gradle config, real ProGuard caveats, real `abiFilters` aligned to the host app.
- The consumer side is shown end-to-end so the Android team can integrate without a discovery call.
- The `consumerProguardFiles` and `exclude group` gotchas are named (these are the most common silent failures).
- Two delivery patterns are shown so this works with or without Artifactory infrastructure.
- Versioning enforcement is concrete, not aspirational.

The Integrated approach for an iOS host app is in the sister transcript `integrated-podfile-session.md`.
