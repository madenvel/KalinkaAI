## Installation

### Android

Download an APK below and install it:

- `kalinka-__VERSION__-arm64-v8a.apk` — most phones (64-bit ARM)
- `kalinka-__VERSION__-armeabi-v7a.apk` — older 32-bit devices
- `kalinka-__VERSION__.apk` — universal (larger; runs on any ABI)

Verify your download against `md5.txt`:

```
md5sum -c md5.txt
```

All release APKs are signed with the Kalinka release key. Certificate SHA-256:

```
79e0051195d444fd531637202870223455fb436b80b75d55ce2c133aa33e11fb
```

### Linux desktop (x64)

Download and extract `kalinka-__VERSION__-linux-x64.tar.gz`, then run
`./install.sh` to register the app (launcher icon + "Kalinka" name).
`./install.sh --uninstall` reverses it. You can also run the `kalinka`
binary directly without installing.
