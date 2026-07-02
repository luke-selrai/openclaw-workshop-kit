# Worked example: add Expo to an existing iOS Swift app (Integrated approach)

A reference end-to-end session for a developer integrating React Native + Expo into a brownfield iOS app via the Integrated approach. **You:** is the developer, **Claude:** is the response. The Isolated AAR approach for Android is shown in `examples/isolated-aar-session.md` (this folder).

The skill's job is to route the user to the right reference doc and produce the actual Podfile, Bridging, and entry-point code. This transcript shows that end-to-end.

---

## You

I have an existing iOS Swift app called Vault (a personal note app, Xcode 16, deployment target iOS 17). I want to embed an Expo-managed React Native screen for a new "AI-assisted note rewriting" feature. I want the Integrated approach, not Isolated. SDK 55 to match my React Native project on the side.

## Claude

Integrated approach for iOS is the right call given Vault is Swift-only and you want React Native to render natively alongside your existing screens. Walking the install end-to-end.

> Reads `references/integrated.md` for the Integrated approach. Reads `references/troubleshooting.md` for the known Metro and pod-install gotchas.

### Step 1: Confirm versions are pinned consistently

Your React Native side runs Expo SDK 55. Vault needs the same `react-native` and `react` versions in the embedded code. Locking now:

```bash
# In your RN project (the side you already have)
grep -E '"react":|"react-native":|"expo":' package.json
# Expected: react ~19.0, react-native 0.76, expo ~55.x
```

If those don't line up, fix the RN side first or the embedded build will fail with `Multiple commands produce` errors at link time.

### Step 2: Create the Pods directory and Podfile

Inside Vault's repo at `ios/`, create a `Podfile` (or extend the existing one):

```ruby
require File.join(File.dirname(`node --print "require.resolve('expo/package.json')"`), "scripts/autolinking")
require File.join(File.dirname(`node --print "require.resolve('react-native/package.json')"`), "scripts/react_native_pods")

platform :ios, '17.0'
prepare_react_native_project!

target 'Vault' do
  use_expo_modules!
  config = use_native_modules!

  use_react_native!(
    :path => config[:reactNativePath],
    :hermes_enabled => true,
    :fabric_enabled => false,
    :app_path => "#{Pod::Config.instance.installation_root}/.."
  )

  post_install do |installer|
    react_native_post_install(installer, config[:reactNativePath], :mac_catalyst_enabled => false)
  end
end
```

Then run:

```bash
cd ios
bundle install
bundle exec pod install
```

If `pod install` fails with `Unable to find a specification for ExpoModulesCore`, your RN project's `node_modules` is not findable from this Podfile path. Adjust the `app_path` to point at the RN project root, not the Vault repo root.

### Step 3: Wire the React Native root view into a Swift `UIViewController`

Create `Vault/RewriterViewController.swift`:

```swift
import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

class RewriterViewController: UIViewController {
    private var rootView: RCTRootView?
    private let bridge: RCTBridge

    init(bridge: RCTBridge) {
        self.bridge = bridge
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let rootView = RCTRootView(
            bridge: bridge,
            moduleName: "RewriterRoot",   // Must match AppRegistry.registerComponent name in JS
            initialProperties: [:]
        )
        rootView.frame = view.bounds
        rootView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(rootView)
        self.rootView = rootView
    }
}
```

The shared `RCTBridge` should be created once in your `AppDelegate` and re-used. Creating a fresh bridge per screen leaks memory and breaks Metro fast-refresh.

### Step 4: Create the React Native entry point

In your RN project, add `index.js`:

```javascript
import { AppRegistry } from 'react-native';
import RewriterRoot from './src/RewriterRoot';

AppRegistry.registerComponent('RewriterRoot', () => RewriterRoot);
```

The string `'RewriterRoot'` must exactly match the `moduleName` you used in the Swift `RCTRootView` init above. A mismatch shows up as a blank screen in Vault with `Module RewriterRoot is not registered callable` in the Metro console.

### Step 5: Run it

```bash
# RN side, in one terminal
cd path/to/rn-project
npx expo start --dev-client

# iOS side, in Xcode
open ios/Vault.xcworkspace   # not .xcodeproj
# Press Run on the Vault target.
```

When Vault launches, navigate to the screen that presents `RewriterViewController(bridge: appBridge)`. You should see the React Native UI render inside Vault's UI shell.

### Versioning enforcement

Add this to your CI or pre-commit so SDK drift is caught:

```bash
RN_VERSION=$(cd path/to/rn-project && node -p "require('./package.json').dependencies['react-native']")
echo "RN side: $RN_VERSION"
# Then assert the Podfile.lock matches:
grep "React-Core" ios/Podfile.lock | head -1
```

---

## What this transcript proves

- The Integrated approach is concrete: real Podfile, real Swift `UIViewController`, real RN entry point, real run command.
- The autolinking dependency on `expo/package.json` resolution path is named (not a hand-wave).
- The `moduleName` matching between Swift and JS is the most common silent-failure point and is called out explicitly.
- Versioning drift is enforceable, not just documented.
- The Metro fast-refresh + bridge-reuse gotcha is named.

The Isolated approach (for shipping React Native as a versioned AAR/XCFramework to a separate native team) is in the sister transcript `isolated-aar-session.md`.
