# expo-module changelog

## [Unreleased] - 2026-05-23

Pass 1 Promising to Production upgrade pass. Vetter scored evidence=3 with the load-bearing weakness "No bundled worked example, neither a complete Swift module nor a complete Kotlin module beyond the trivial hello function."

### Added

- `examples/swift-native-module-session.md` complete non-trivial iOS Swift module: static constant, async function with error rejection, event emitter with `OnStartObserving`/`OnStopObserving` lifecycle hooks, TypeScript surface, JS usage, smoke verification path.
- `examples/kotlin-native-module-session.md` Android Kotlin counterpart with feature parity. Calls out unit differences (hPa vs kPa), threading model, relative-altitude calculation, battery profile.
- SKILL.md "Bundled artifacts" pointer at the top.

### Not touched

- The router-only SKILL.md body that points at `references/create-expo-module.md`, `references/native-module.md`, `references/native-view.md`, `references/lifecycle.md`, `references/config-plugin.md`, `references/module-config.md` unchanged.
- No tests/, scripts/, or workflow files touched.
