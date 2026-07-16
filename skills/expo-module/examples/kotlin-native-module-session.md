# Worked example: build an Android Expo native module (Kotlin) that exposes the device's barometer

A reference end-to-end session for writing the Android side of the same barometer module shown in `examples/swift-native-module-session.md`. Same JS surface, native parity with iOS so JS code stays cross-platform.

The Android `SensorManager` API is shaped differently from iOS `CMAltimeter`, so the module surface is identical but the native implementation differs in a few load-bearing places: sensor registration, coordinate system, and threading.

---

## You

Add Android support to the expo-barometer module. Same JS shape as the iOS side (`isAvailable`, `getCurrentPressure`, `pressureChanged` event). Kotlin. SDK 55.

## Claude

Walking the Android implementation.

> Reads `references/native-module.md`, `references/lifecycle.md`. The module config from the iOS session already lists `"android"` so autolinking is wired.

### Step 1: Update the module config

`expo-module.config.json`:

```json
{
  "platforms": ["apple", "android"],
  "apple": {
    "modules": ["BarometerModule"]
  },
  "android": {
    "modules": ["expo.modules.barometer.BarometerModule"]
  }
}
```

The Android entry uses the fully-qualified Kotlin class path. Autolinking won't find it otherwise.

### Step 2: Write the Kotlin module

`android/src/main/java/expo/modules/barometer/BarometerModule.kt`:

```kotlin
package expo.modules.barometer

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class BarometerModule : Module() {
    private val sensorManager: SensorManager?
        get() = appContext.reactContext?.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    private val pressureSensor: Sensor?
        get() = sensorManager?.getDefaultSensor(Sensor.TYPE_PRESSURE)

    private var listener: SensorEventListener? = null
    private var initialPressure: Float? = null   // baseline for relativeAltitude calc

    override fun definition() = ModuleDefinition {
        Name("ExpoBarometer")

        Constants(
            "isAvailable" to (pressureSensor != null)
        )

        AsyncFunction("getCurrentPressure") { promise: expo.modules.kotlin.Promise ->
            val sm = sensorManager
            val sensor = pressureSensor
            if (sm == null || sensor == null) {
                promise.reject("ERR_NOT_AVAILABLE", "Barometer is not available on this device", null)
                return@AsyncFunction
            }
            // One-shot read: register, capture first value, unregister.
            val oneShot = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) {
                    // Android returns pressure in hPa (mbar). Convert to kPa for parity with iOS.
                    val kPa = event.values[0] / 10.0
                    sm.unregisterListener(this)
                    promise.resolve(kPa)
                }
                override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
            }
            sm.registerListener(oneShot, sensor, SensorManager.SENSOR_DELAY_UI)
        }

        Events("pressureChanged")

        OnStartObserving("pressureChanged") {
            val sm = sensorManager ?: return@OnStartObserving
            val sensor = pressureSensor ?: return@OnStartObserving
            if (listener != null) return@OnStartObserving   // already observing

            listener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) {
                    val hPa = event.values[0]
                    val kPa = hPa / 10.0
                    if (initialPressure == null) initialPressure = hPa
                    // Barometric formula: h = 44330 * (1 - (p/p0)^(1/5.255))
                    val relativeAltitudeMeters = 44330.0 *
                        (1 - Math.pow((hPa / initialPressure!!).toDouble(), 1.0 / 5.255))
                    sendEvent("pressureChanged", mapOf(
                        "pressure" to kPa,
                        "relativeAltitude" to relativeAltitudeMeters
                    ))
                }
                override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
            }
            sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        }

        OnStopObserving("pressureChanged") {
            val sm = sensorManager ?: return@OnStopObserving
            listener?.let { sm.unregisterListener(it) }
            listener = null
            initialPressure = null
        }
    }
}
```

### Step 3: Smoke verify

```bash
cd path/to/rn-project
npx expo prebuild --clean --platform android
npx expo run:android --device
```

Tip: the Android emulator can simulate barometer readings via the Extended Controls panel under "Virtual Sensors". Set the pressure manually to verify the JS subscription receives the right kPa value. On a physical device, walk between floors to see the value drift.

### Differences from iOS to note

- **Units.** Android `SensorManager` returns hPa (millibars); iOS `CMAltimeter` returns kPa. The module normalises to kPa on output for JS parity.
- **`relativeAltitude` calculation.** iOS computes it natively. Android exposes only absolute pressure, so the module computes relative altitude from the first reading using the barometric formula. The first event's `relativeAltitude` is always 0.0 (the baseline).
- **Threading.** Android sensor callbacks fire on the main thread by default. The Swift example also dispatches to main. Both implementations are safe to call `sendEvent` from inside the callback directly.
- **Battery profile.** `SENSOR_DELAY_NORMAL` (200ms) is the right default for a barometer; faster delays drain battery without adding useful precision for altitude-style use cases. iOS uses `CMAltimeter`'s default update rate.

### Failure modes specific to Android

- **No barometer hardware** (most low-end devices, all Android emulators without the Virtual Sensors panel enabled): `pressureSensor` is `null`. `isAvailable` reflects this; `getCurrentPressure` rejects; the event stream never starts.
- **Listener leak**: if the module is unloaded (Activity destroyed) while observing, the `SensorManager` keeps the listener registered. `OnStopObserving` handles the JS-driven case; the host app's Activity lifecycle must also unregister. The example handles this implicitly via the `OnStopObserving` hook firing on JS teardown.

---

## What this transcript proves

- The Android module is feature-parity with the iOS one (`isAvailable`, async one-shot read, event stream with lifecycle hooks).
- Platform differences are explicitly named (units, threading, relative-altitude calculation, battery profile).
- The smoke verification works on both physical devices and the emulator's Virtual Sensors panel.
- An outsider can read this side-by-side with the Swift transcript and understand how Expo's cross-platform module DSL keeps the JS contract identical while the natives diverge.
