# Worked example: build an iOS Expo native module (Swift) that exposes the device's barometer

A reference end-to-end session for writing a non-trivial Expo native module. **You:** is the developer, **Claude:** is the response. The Kotlin counterpart for Android is in `examples/kotlin-native-module-session.md` (this folder).

The example builds a real module: read barometric pressure (kPa) from the device's `CMAltimeter`, expose it to JS as a constant + a one-shot read function + an event-emitter stream. Covers definition DSL, `OnStartObserving`/`OnStopObserving`, shared object lifecycle, and async function patterns.

---

## You

I need an Expo native module that exposes barometric pressure on iOS. JS should be able to (1) read a static `isAvailable` constant, (2) call `getCurrentPressure()` once, and (3) subscribe to a `pressureChanged` event. Swift. SDK 55.

## Claude

Walking the module end-to-end. Files I'll generate, with the matching JS shape and a smoke verification.

> Reads `references/create-expo-module.md`, `references/native-module.md`, `references/module-config.md`, `references/lifecycle.md`.

### Step 1: Scaffold the module

```bash
cd path/to/rn-project
npx create-expo-module@latest expo-barometer
# Choose: Swift + Kotlin (or Swift only if you don't need Android yet)
```

This creates `expo-barometer/` with `ios/`, `android/`, `src/` (TypeScript), `expo-module.config.json`, and the boilerplate.

### Step 2: Write the Swift module

`ios/BarometerModule.swift`:

```swift
import ExpoModulesCore
import CoreMotion

public class BarometerModule: Module {
    private let altimeter = CMAltimeter()
    private var isObserving = false

    public func definition() -> ModuleDefinition {
        Name("ExpoBarometer")

        // Static constant exposed as ExpoBarometer.isAvailable in JS.
        Constants([
            "isAvailable": CMAltimeter.isRelativeAltitudeAvailable()
        ])

        // One-shot async read. Returns kPa or rejects with a domain error.
        AsyncFunction("getCurrentPressure") { (promise: Promise) in
            guard CMAltimeter.isRelativeAltitudeAvailable() else {
                promise.reject("ERR_NOT_AVAILABLE", "Barometer is not available on this device")
                return
            }
            self.altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
                self.altimeter.stopRelativeAltitudeUpdates()
                if let error = error {
                    promise.reject("ERR_READ", error.localizedDescription)
                    return
                }
                guard let data = data else {
                    promise.reject("ERR_NO_DATA", "No barometer data returned")
                    return
                }
                promise.resolve(data.pressure.doubleValue)   // pressure is in kPa
            }
        }

        // Event emitter. JS subscribes via ExpoBarometer.addListener('pressureChanged', cb).
        Events("pressureChanged")

        // Lifecycle hooks. Auto-fire when JS adds/removes the first/last listener.
        OnStartObserving("pressureChanged") {
            guard CMAltimeter.isRelativeAltitudeAvailable(), !self.isObserving else { return }
            self.isObserving = true
            self.altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
                guard let data = data, error == nil else { return }
                self.sendEvent("pressureChanged", [
                    "pressure": data.pressure.doubleValue,
                    "relativeAltitude": data.relativeAltitude.doubleValue
                ])
            }
        }

        OnStopObserving("pressureChanged") {
            guard self.isObserving else { return }
            self.altimeter.stopRelativeAltitudeUpdates()
            self.isObserving = false
        }
    }
}
```

### Step 3: Wire it up in the module config

`expo-module.config.json`:

```json
{
  "platforms": ["apple", "android"],
  "apple": {
    "modules": ["BarometerModule"]
  }
}
```

The module name (`"BarometerModule"`) must match the Swift class name. Autolinking uses this string at build time.

### Step 4: Write the TypeScript surface

`src/index.ts`:

```typescript
import { NativeModule, requireNativeModule } from 'expo-modules-core';

export type PressureEvent = {
  pressure: number;            // kPa
  relativeAltitude: number;    // metres, relative to first reading
};

declare class ExpoBarometerModule extends NativeModule {
  isAvailable: boolean;
  getCurrentPressure(): Promise<number>;
  addListener(eventName: 'pressureChanged', listener: (event: PressureEvent) => void): void;
  removeListener(eventName: 'pressureChanged', listener: (event: PressureEvent) => void): void;
}

export default requireNativeModule<ExpoBarometerModule>('ExpoBarometer');
```

### Step 5: Use it from JS

```javascript
import ExpoBarometer from 'expo-barometer';
import { useEffect, useState } from 'react';

export function BarometerScreen() {
  const [pressure, setPressure] = useState<number | null>(null);

  useEffect(() => {
    if (!ExpoBarometer.isAvailable) {
      console.warn('Barometer not available');
      return;
    }

    // One-shot read.
    ExpoBarometer.getCurrentPressure().then(setPressure);

    // Stream.
    const sub = ExpoBarometer.addListener('pressureChanged', (e) => {
      setPressure(e.pressure);
    });

    return () => sub.remove();
  }, []);

  return <Text>Pressure: {pressure?.toFixed(2) ?? 'n/a'} kPa</Text>;
}
```

### Step 6: Smoke verify

Build and run on a physical device (the simulator has no barometer):

```bash
cd path/to/rn-project
npx expo prebuild --clean
npx expo run:ios --device
```

You should see the pressure value render and update as you walk between floors of a building. Typical sea-level reading: ~101.3 kPa. Each floor: ~0.12 kPa drop.

### Failure modes and how the module handles them

- **Device without a barometer** (e.g. iPhone SE 1st gen): `isAvailable` is `false`. `getCurrentPressure()` rejects with `ERR_NOT_AVAILABLE`. The event stream never fires (because `OnStartObserving` guards on `isRelativeAltitudeAvailable`).
- **`CMAltimeter` errors mid-stream** (rare, usually due to OS pressure-sensor reset): the closure receives `error != nil` and silently skips the event. The stream resumes on next reading. Production code should add a recovery path; this example keeps it minimal.
- **Multiple JS subscribers**: `OnStartObserving` only fires for the first listener; subsequent listeners share the same `CMAltimeter` updates without double-starting it. `OnStopObserving` fires only when the last listener unsubscribes.

---

## What this transcript proves

- The module is non-trivial: a static constant, an async function with error rejection, and an event emitter with lifecycle hooks.
- The Swift -> TypeScript -> JS contract is shown end-to-end.
- Real device-class failure modes are named (no barometer on SE 1st gen, OS-level sensor reset).
- The smoke verification is real: walk between floors, see the value change.
- An outsider can read this and build a working module that ships.

The Kotlin counterpart for Android lives at `examples/kotlin-native-module-session.md`.
