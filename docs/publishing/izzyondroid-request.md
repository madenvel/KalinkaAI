# IzzyOnDroid inclusion request (draft)

IzzyOnDroid migrated from GitLab (now archived/read-only) to Codeberg.
File a new issue at https://codeberg.org/IzzyOnDroid/repodata/issues
(choose the "Add App" template if offered — needs a free Codeberg
account) with the following content. Their inclusion policy:
https://izzyondroid.org/docs/general/AppInclusionPolicy/

---

**Title:** Add Kalinka (org.kalinka.kalinka)

**App name:** Kalinka

**Repo URL:** https://github.com/madenvel/KalinkaAI

**License:** Apache-2.0

**Releases:** APKs are attached to GitHub releases (tagged `v<X.Y.Z>`):
https://github.com/madenvel/KalinkaAI/releases
Per-ABI splits are provided (`kalinka-<version>-arm64-v8a.apk` ~20 MB)
alongside a universal APK; please pick the arm64-v8a artifact if a single
APK is preferred.

**APK signing certificate SHA-256:**
`79e0051195d444fd531637202870223455fb436b80b75d55ce2c133aa33e11fb`

**Description:** Kalinka is a remote control app for the open-source
Kalinka Music Server (https://github.com/madenvel/KalinkaPlayer) —
browse your library, queue music and control playback on your hi-fi
from the phone. Fastlane metadata (descriptions, icon, screenshots,
changelogs) is in the repo under `fastlane/metadata/android/`.

**Anti-features:** none known — no trackers, no ads, no proprietary
dependencies; the app only talks to the user's own server on the
local network.

---

Notes for us (not part of the issue):
- Izzy's bot pulls new APKs from GitHub releases automatically after inclusion.
- Keep attaching per-ABI APKs to future releases so the app stays inside
  Izzy's per-app size budget.
