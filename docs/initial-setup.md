# Initial setup

Getting from zero to music playing takes three steps: install the server,
point it at your music, connect the app.

## 1. Install Kalinka Music Server

On the machine that will play the music (Raspberry Pi or any Debian-based
Linux box connected to your audio gear), run:

```bash
curl -fsSL https://raw.githubusercontent.com/madenvel/KalinkaPlayer/main/scripts/install-release.sh | sudo bash
```

The script detects your architecture, downloads the matching packages from
the [latest server release](https://github.com/madenvel/KalinkaPlayer/releases/latest),
and installs them with `apt` so system dependencies come along automatically.
Upgrading later is the same command. Supported systems: Raspberry Pi OS
(trixie, 64-bit) / Debian 13 on ARM, and Ubuntu 24.04 on x86_64.

<details>
<summary>Manual install (without the script)</summary>

Download from the
[latest release](https://github.com/madenvel/KalinkaPlayer/releases/latest):
the server package matching your OS — `…debian-13.arm64.deb` for Raspberry
Pi OS / Debian 13, `…ubuntu-24.04.amd64.deb` for Ubuntu 24.04 — plus **all**
the `_all.deb` plugin/SDK packages and `SHA256SUMS`. Then, in the download
directory:

```bash
sha256sum -c SHA256SUMS --ignore-missing   # verify downloads
sudo apt install ./*.deb
```

</details>

The server starts automatically after installation and announces itself on
the local network. Check it came up with:

```bash
journalctl -u kalinka -f
```

## 2. Put your music where the server can see it

The easy path: the installer creates `/srv/kalinka/music`, the server
watches it out of the box, and it is writable by everyone — just copy your
files in (locally, over SFTP, however you like) and skip to step 3.

To use a collection that already lives somewhere else (USB drive, NAS
mount, a folder in your home), point the **Local files** module at it in
step 3 instead. One thing to know: the server runs as the unprivileged
system user `kalusr`, so the files must be **readable by `kalusr`** —
world-readable (`o+rX`) or group-readable with `kalusr` in the group.
Home folders work (the service sees them read-only), but on systems that
create homes with private permissions you may need to open a path in:

```bash
chmod o+X /home/<you>                    # let the service reach into your home
chmod -R o+rX /home/<you>/Music          # and read the collection
```

For a USB/NAS mount the same rule applies — check the files are readable
by other users (`ls -l`), and fix with `chmod -R o+rX <mount>/music` if not.

## 3. Connect the app and finish configuration

(Illustrated walkthrough with screenshots: see the
[app manual](app-manual.md).)

1. Install the Kalinka app
   ([releases](https://github.com/madenvel/KalinkaAI/releases)) on a phone
   on the same network.
2. On first launch the app scans the network and lists every Kalinka server
   it finds — pick yours and tap **Connect**. (No server found? See
   [Troubleshooting](#troubleshooting).)
3. Tap the **green status dot** (top-right of the search bar) →
   **Server settings**.
4. In the **Input Modules** tab, open **Local files** and check
   **Music folders**: the default `/srv/kalinka/music` is already set —
   add (or replace it with) your own path if your collection lives
   elsewhere, e.g. a USB/NAS mount.
5. In the **General** tab you can adjust the basics visible in the
   simple tier:
   - **Service name** — how the server appears in network discovery
     (useful when you run more than one).
   - **Audio output** — pick the ALSA device connected to your amplifier.
   - **Device automation** — auto power on/off for supported external
     devices (e.g. Yamaha MusicCast) and the pause timeout.
   Advanced options live behind the **EXPERT** toggle (top-right).

The indexer picks up the folder within the scan interval (15 minutes by
default) and additionally watches for file changes; a freshly added
collection starts appearing in search within moments of the first scan
pass.

### Optional: AI search

AI natural-language search runs entirely on the server. On first use the
server downloads its audio-embedding model (~285 MB, one-time) and then
indexes your collection in the background — on a Raspberry Pi the initial
embedding pass can take a while for large libraries. Search works
normally (text matching) while that runs; AI results blend in as tracks
get embedded.

## Troubleshooting

- **Library stays empty** — check the journal for path errors:
  `journalctl -u kalinka | grep -i "music\|folder\|scan"`. Almost always
  the folder path is wrong or the files are not readable by the `kalusr`
  service user (see step 2).
- **App finds no server** — phone and server must be on the same
  network/VLAN, and mDNS (UDP 5353 multicast) must not be blocked by the
  router's "client isolation". You can always connect manually:
  discovery screen → **Enter Address Manually** → `<server-ip>:8000`.
- **No sound** — check the ALSA device selection in **General →
  Audio output**; HDMI vs. analog vs. USB DAC are separate devices.
