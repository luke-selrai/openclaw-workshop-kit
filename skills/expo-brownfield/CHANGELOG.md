# expo-brownfield changelog

## [Unreleased] - 2026-05-23

Pass 1 Promising to Production upgrade pass. Vetter scored evidence=3 with the load-bearing weakness "No bundled worked example, neither a complete Isolated AAR consumption nor a complete Integrated Podfile snippet."

### Added

- `examples/integrated-podfile-session.md` complete iOS Integrated approach transcript: Podfile, Swift UIViewController, RN entry point, run command, versioning enforcement, common silent failures named.
- `examples/isolated-aar-session.md` complete Android Isolated AAR transcript: library Gradle config, ProGuard caveats, ABI filters, signing, two delivery patterns (Maven vs flatDir), consumer-side Application setup, versioning enforcement.
- SKILL.md "Bundled artifacts" pointer at the top.

### Not touched

- The router-only SKILL.md body that points at `references/brownfield-integrated.md`, `references/brownfield-isolated.md`, `references/comparison.md`, `references/troubleshooting.md` unchanged. The references are the canonical implementation detail; the examples are the proof.
- No tests/, scripts/, or workflow files touched.
