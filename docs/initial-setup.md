# Initial setup

Getting from zero to music playing takes three steps: install the server,
point it at your music, connect the app.

## 1. Install Kalinka Music Server

On the machine that will play the music (Raspberry Pi or any Debian-based
Linux box connected to your audio gear), download the packages from the
[latest server release](https://github.com/madenvel/KalinkaPlayer/releases)
and install them in one transaction:

```bash
md5sum -c md5.txt   # verify downloads
sudo apt install ./kalinka-plugin-sdk_*_all.deb \
                 ./kalinka-server-*.deb \
                 ./kalinka-plugin-localfiles_*_all.deb
```

The server starts automatically after installation and announces itself on
the local network. Check it came up with:

```bash
journalctl -u kalinka -f
```

## 2. Put your music where the server can see it

This is the step most likely to need manual attention.

The server runs as the unprivileged system user `kalusr` inside a systemd
sandbox. Two consequences:

- **Home directories are off-limits.** The service runs with
  `ProtectHome=yes`, so anything under `/home/...` is invisible to it —
  a music folder there will not work even if the path is correct and
  world-readable.
- **The default path does not exist yet.** The stock configuration points
  at `~/Music` of the service user, which is not created on install. Until
  you set a real folder, the library will simply be empty.

Good locations for the collection:

| Location | Typical use |
|---|---|
| `/srv/music` | dedicated folder on the system disk |
| `/media/<name>` / `/mnt/<name>` | USB drive or NAS mount |

Create the folder (if needed), make it readable by the service, and drop
your files in:

```bash
sudo mkdir -p /srv/music
sudo chgrp -R kalusr /srv/music
sudo chmod -R g+rX /srv/music
```

For an existing USB/NAS mount you only need the permission part — the
files must be readable by user/group `kalusr` (`g+rX` or world-readable).

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
4. In the **Input Modules** tab, open **Local files** and set
   **Music folders** to your collection path (e.g. `/srv/music`).
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
  the folder is under `/home` (sandbox: invisible), missing, or not
  readable by `kalusr`.
- **App finds no server** — phone and server must be on the same
  network/VLAN, and mDNS (UDP 5353 multicast) must not be blocked by the
  router's "client isolation". You can always connect manually:
  discovery screen → **Enter Address Manually** → `<server-ip>:8000`.
- **No sound** — check the ALSA device selection in **General →
  Audio output**; HDMI vs. analog vs. USB DAC are separate devices.
