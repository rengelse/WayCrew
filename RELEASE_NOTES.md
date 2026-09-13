# WayCrew Release Notes

## v0.2.19 – Dependency Resolution Fix

- Updated `package_info_plus` to `^10.2.1` to match the dependency requirement from `geolocator ^14.0.3`.
- Fixes GitHub Actions failure during `flutter create` / dependency resolution.
- Retains Java 21, signed release APK builds, GitHub Releases publishing and in-app update checks from v0.2.18.
- No Supabase migration in this release.

## v0.2.18 – Release Build & GitHub Update Check

- GitHub Actions builds a signed release APK on both `main` pushes and `v*` tags.
- Release APK is named `WayCrew-vX.Y.Z.apk`.
- Tags are validated against the version in `pubspec.yaml` before publishing a GitHub Release.
- WayCrew checks `rengelse/WayCrew` GitHub Releases automatically at startup.
- A new-version dialog shows installed and available versions and links directly to the APK asset when present.
- Update checks are throttled to avoid unnecessary GitHub API traffic and repeated prompts.
- Settings > Om now shows the installed version and includes manual `Sjekk etter oppdatering`.
- No Supabase migration in this release.

## v0.2.17 – Java 21 CI Fix

- GitHub Actions uses Temurin JDK 21 for MapLibre Android compilation.
