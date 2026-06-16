---
name: release
description: Cut a new Kalinka app release — bump the version, build the signed APKs + Linux desktop tarball, and publish a GitHub release with assets and md5.txt. Use when the user asks to "release", "publish a release", "bump the version", "cut a version", or "make a new release".
---

# Kalinka release

Builds and publishes a Kalinka app release to GitHub. Covers a patch, minor, or
major bump. The repo is `madenvel/KalinkaAI`; releases go to GitHub Releases.

## Versioning

`pubspec.yaml` holds `version: <semver>+<build>` (e.g. `0.2.0+3`).
- **patch** `0.1.1 → 0.1.2`, **minor** `0.1.1 → 0.2.0`, **major** `0.1.1 → 1.0.0`.
- The **build number** (`+N`) increments by 1 every release, regardless of bump type.
- Android `versionCode = flutter.versionCode` = the build number. With
  `--split-per-abi`, Flutter offsets it by `1000 × abiIndex`; **arm64-v8a uses
  index 2**, so the indexed code IzzyOnDroid tracks is `2000 + build`
  (build `3` → `2003`). Name the fastlane changelog file after that number.

## Steps

1. **Find the current version.** `grep '^version:' pubspec.yaml`. Decide the new
   semver per the bump type the user asked for, and increment the build number.

2. **Bump `pubspec.yaml`.** Edit the `version:` line to `<newsemver>+<newbuild>`.

3. **Write the fastlane changelog.** Create
   `fastlane/metadata/android/en-US/changelogs/<arm64-versionCode>.txt`
   (= `2000 + build`). Keep it short, bulleted, user-facing. Source the points
   from `git log <prev-tag>..HEAD --oneline`.

4. **Commit, tag, push.** Build artifacts MUST come from the clean tag checkout
   so the embedded version (`git describe`) is clean — commit and tag *before*
   building.
   ```bash
   git add pubspec.yaml fastlane/metadata/android/en-US/changelogs/<code>.txt
   git commit -m "Bump version to <newsemver>"   # add Co-Authored-By trailer
   git tag -a v<newsemver> -m "Kalinka <newsemver>"
   git push origin main && git push origin v<newsemver>
   git describe --tags --dirty   # must print exactly "v<newsemver>" (no -dirty)
   ```
   `main` is protected but the maintainer's pushes bypass the rule — a
   "Bypassed rule violations" notice on push is expected, not an error.

5. **Build artifacts** (from the clean checkout, via `scripts/build_release.sh`
   which embeds `--dart-define=GIT_DESCRIBE`):
   ```bash
   mkdir -p dist
   # per-ABI (produces armeabi-v7a, arm64-v8a, x86_64; we ship the first two)
   scripts/build_release.sh apk --split-per-abi
   cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   dist/kalinka-<v>-arm64-v8a.apk
   cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk dist/kalinka-<v>-armeabi-v7a.apk
   # universal
   scripts/build_release.sh apk
   cp build/app/outputs/flutter-apk/app-release.apk dist/kalinka-<v>.apk
   # Linux desktop
   scripts/build_release.sh linux
   tar -czf dist/kalinka-<v>-linux-x64.tar.gz \
     --transform 's,^bundle,kalinka-<v>-linux-x64,' \
     -C build/linux/x64/release bundle
   ```
   If a build fails with an invalid-Java-home error, check
   `~/.gradle/gradle.properties` (`org.gradle.java.home` pins the Android Studio
   flatpak JBR 21; Fedora's system Java can't run Gradle 8.12).

6. **Checksums + signing check.**
   ```bash
   cd dist && md5sum kalinka-<v>-arm64-v8a.apk kalinka-<v>-armeabi-v7a.apk \
     kalinka-<v>.apk kalinka-<v>-linux-x64.tar.gz > md5.txt && cd ..
   # verify signing cert is the expected release key
   "$(ls ~/Android/Sdk/build-tools/*/apksigner | sort -V | tail -1)" \
     verify --print-certs dist/kalinka-<v>-arm64-v8a.apk | grep SHA-256
   ```
   Expected cert SHA-256: `79e0051195d444fd531637202870223455fb436b80b75d55ce2c133aa33e11fb`.
   If it doesn't match, STOP — `android/key.properties` is missing and the APK
   fell back to debug signing.

7. **Publish.** Write release notes (Added / Changed / Fixed, an Installation
   section with the md5 verify instructions, the cert SHA-256, and a Linux
   desktop note — mirror the previous release's body) to a temp file, then:
   ```bash
   gh release create v<v> --title "Kalinka <v>" --notes-file /tmp/relnotes.md \
     dist/kalinka-<v>-arm64-v8a.apk dist/kalinka-<v>-armeabi-v7a.apk \
     dist/kalinka-<v>.apk dist/kalinka-<v>-linux-x64.tar.gz dist/md5.txt
   ```

## Notes

- Always attach the per-ABI arm64-v8a APK — IzzyOnDroid's 30 MB budget indexes it.
- We ship arm64-v8a, armeabi-v7a, universal, Linux tarball, md5.txt. x86_64 is
  built by `--split-per-abi` but not published.
- `dist/` is scratch; it's fine to leave or clean up after publishing.
