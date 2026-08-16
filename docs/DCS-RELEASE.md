# DCS Norway Remote Desktop Client — releases & updates

Operators get updates from **GitHub Releases** (pre-built installers), not by compiling source on their PCs.

Windows, Linux, macOS (Apple Silicon and Intel), Android, and iOS share the same DCS client:
branding, Available devices only (no Recent / Favorites / Discovered / Address book / Remote ID),
and the DCS About page.

## Publish a new build

1. Bump the version in source so clients detect “newer”:
   - [`Cargo.toml`](../Cargo.toml) / [`libs/portable/Cargo.toml`](../libs/portable/Cargo.toml)
   - Commit the updated [`Cargo.lock`](../Cargo.lock) (CI uses `cargo build --locked`)
   - Default `VERSION` in [`.github/workflows/flutter-build.yml`](../.github/workflows/flutter-build.yml) (must match the release tag for asset names)
   - [`flutter/pubspec.yaml`](../flutter/pubspec.yaml) version (optional consistency)
2. Commit and push to the branding branch.
3. Create and push a **tag** matching the version string used in asset names, e.g.:
   - `1.4.10`
   - `1.4.9-2`  
   Prefer tags **without** a leading `v` so updater filenames stay simple (`rustdesk-1.4.10-x86_64.exe`).
4. Start the Windows build:
   - **Preferred while the workflow lives only on the branding branch:**  
     Actions → **DCS Windows Release** → Run workflow (branch = branding branch) → set `release_tag` to `1.4.10`.  
     Or: `gh workflow run dcs-windows-release.yml --ref <branding-branch> -f release_tag=1.4.10`
   - **Automatic on tag push** works only after this workflow file exists on the repo **default** branch (GitHub limitation).
5. Wait for workflow **DCS Windows Release**. It calls the full Flutter build reusable workflow; ensure `VERSION` in `.github/workflows/flutter-build.yml` matches the tag (asset name `rustdesk-{tag}-x86_64.exe`).
6. On the GitHub Release for that tag, confirm assets:
   - `rustdesk-{tag}-x86_64.exe` — used by in-app updater
   - `DCS-Norway-RDC-{version}-x86_64-install.exe` — human-friendly Windows alias
   - `DCS-Norway-RDC-{version}-x86_64.apk` — DCS-branded Android client (emulator / x86_64)
   - `DCS-Norway-RDC-{version}-x86_64.deb` — Linux (when built)
   - `DCS-Norway-RDC-{version}-x86_64.dmg` — macOS Intel (when built)
   - `DCS-Norway-RDC-{version}-aarch64.dmg` — macOS Apple Silicon (when built)
   - `DCS-Norway-RDC-{version}-ios.ipa` — iPad and iPhone (same IPA)
   Release is marked **non-prerelease** so clients can find it.

Linux and both macOS architectures use the same Flutter desktop client as Windows (RdClient home,
Available devices, DCS About). iOS uses the same Flutter mobile client as Android.

### Android (DCS-branded APK)

The stock Flutter build already publishes `rustdesk-{tag}-*.apk` assets. For the
**DCS Norway** Android client (Available devices only, DCS branding), attach:

- `DCS-Norway-RDC-{version}-x86_64.apk`

Upload via the release page, or after a local/CI build:

```bash
gh release upload 1.4.10 ./DCS-Norway-RDC-1.4.10-x86_64.apk --clobber
```

Notes:
- x86_64 APK is for Android emulators and x86_64 devices.
- Physical phones normally need `arm64-v8a` (separate build) — add
  `DCS-Norway-RDC-{version}-aarch64.apk` the same way when available.

### Linux (.deb)

Build the Flutter Linux client from this branding branch, then attach:

- `DCS-Norway-RDC-{version}-x86_64.deb`
- `DCS-Norway-RDC-{version}-aarch64.deb` (when built)

The `.desktop` launcher name is **DCS Norway**. The on-disk binary stays `rustdesk` so packaging
paths remain compatible.

### macOS (.dmg) — Apple Silicon and Intel

Both architectures share `flutter/macos/` (display name **DCS Norway**, DCS app icon). Attach:

- `DCS-Norway-RDC-{version}-aarch64.dmg` — Apple Silicon
- `DCS-Norway-RDC-{version}-x86_64.dmg` — Intel

The `.app` product name stays `RustDesk.app` for signing/CI; Finder and the Dock show **DCS Norway**.

### iPad / iPhone (`.ipa`)

iPad and iPhone use the **same** DCS Flutter mobile client as Android (Available devices,
DCS header, DCS About). The device family is iPhone + iPad.

Website / GitHub Releases file:

- `DCS-Norway-RDC-{version}-ios.ipa`

Example:

```
https://github.com/Chesster1981/RustDesk/releases/download/1.4.10/DCS-Norway-RDC-1.4.10-ios.ipa
```

Build and publish:

1. Actions → **DCS iOS Release** → Run workflow (branch = branding branch) → `release_tag` = `1.4.10`
2. Or run **DCS Windows Release**, which also builds the iOS job in the Flutter workflow

The IPA is unsigned (no App Store team on this fork). Install on iPad with **Sideloadly**,
**AltStore**, or Apple Configurator using an Apple ID. Sideloadly re-signs the IPA on a Mac
or Windows PC; the iPad must be connected (or use a wireless pairing). Free Apple IDs last
7 days per sign; a paid Developer account lasts a year.

Do **not** link the Android `.apk` or macOS `.dmg` for iPad.

Manual run (same as step 4): Actions → **DCS Windows Release** → Run workflow.

## How clients update

- On startup (if **Check for software update on startup** is enabled — default on): queries  
  `https://api.github.com/repos/Chesster1981/RustDesk/releases`
- Settings → **About** → **Check for updates**
- A newer tag is offered when it has a DCS client asset (`.exe`, `.deb`, `.dmg`, `.apk`, …).
  Windows can download + `--update` install; Linux / macOS / mobile open the GitHub Release page.

## Local test (no tag)

Build and run Release as usual; packing an installer is optional until you want to ship.

## Notes

- Compile-from-source on operator machines is **not** supported.
- Windows x64 is the primary automated release target; Linux / macOS / iOS use the same branded
  source and are packaged from this branch.
- Code signing uses existing fork secrets when configured; unsigned builds are fine for internal DCS use.
