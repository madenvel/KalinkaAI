# Kalinka

**A self-hosted, open-source Hi-Fi music system for Raspberry Pi and Linux — with on-device AI search over your own library.**

Ask for a mood, get a queue. Semantic search turns a phrase like
_"something melancholic for tonight"_ into matching tracks — running locally on
your own hardware, no cloud and no subscription:

<img src="docs/images/demo.gif" alt="Semantic search demo: searching for 'something melancholic for tonight'" width="280">

**This repository is the Kalinka app** — the cross-platform remote control
(Android, Linux desktop, web). The music is served by the separate
**[Kalinka Music Server](https://github.com/madenvel/KalinkaPlayer)**: a
lightweight backend with a C++/ALSA audio engine, the library indexer and
metadata-enrichment pipeline, and the CLAP semantic-search engine. You need
both — the app talks to a server running on your network.

Website: [kalinkaplayer.com](https://kalinkaplayer.com)

## Install the app

<a href="https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/madenvel/KalinkaAI"><img src="https://raw.githubusercontent.com/ImranR98/Obtainium/main/assets/graphics/badge_obtainium.png" alt="Get it on Obtainium" height="54"></a>

[Obtainium](https://github.com/ImranR98/Obtainium) installs the app straight
from GitHub Releases and keeps it updated — tap the badge (on your phone, with
Obtainium installed) and it pre-fills this repo. Prefer to grab a file
yourself? Everything is on the [releases page](https://github.com/madenvel/KalinkaAI/releases).

- **Android** — each release ships three APKs. Pick **`arm64-v8a`** unless your
  phone is ancient (**`armeabi-v7a`** for old 32-bit devices); the unsuffixed
  universal APK runs on anything but is larger. Obtainium will ask which one —
  choose `arm64-v8a`.
- **Linux desktop (x64)** — download and extract the `linux-x64` tarball and run
  `./install.sh` (registers the launcher icon; `--uninstall` reverses it), or
  just run the `kalinka` binary directly.

All release APKs are signed with the Kalinka release key. Certificate SHA-256
(Obtainium can pin it):

```
79e0051195d444fd531637202870223455fb436b80b75d55ce2c133aa33e11fb
```

## Getting started

The app is only half the system — you also need the server running.

- **[Initial setup guide](docs/initial-setup.md)** — installing the server,
  pointing it at your music collection, and connecting the app.
- **[App manual](docs/app-manual.md)** — illustrated tour: the setup
  wizard, the server chip and settings, music folders, AI search and
  queueing.

## License
- Source code: Apache License 2.0 (see LICENSE and NOTICE).
- Visual assets (icons, logos, images): Private license (see LICENSE-ASSETS).

Visual assets are not open-source in this repository and require prior author
permission for use.

Permission contact:
Dmitry Savin <envelsavinds@gmail.com>

## Distribution
- Open-source/community builds: You can distribute the code under Apache 2.0, but replace visual assets with your own assets unless you have explicit author permission.
- Official asset redistribution: Requires prior written permission from the author.
