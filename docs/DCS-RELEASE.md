# DCS Norway Remote Desktop Client — releases & updates

Operators get updates from **GitHub Releases** (pre-built `.exe`), not by compiling source on their PCs.

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
   Release is marked **non-prerelease** so clients can find it.

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

Manual run (same as step 4): Actions → **DCS Windows Release** → Run workflow.

## How clients update

- On startup (if **Check for software update on startup** is enabled — default on): queries  
  `https://api.github.com/repos/Chesster1981/RustDesk/releases`
- Settings → **About** → **Check for updates**
- If a newer tag has `rustdesk-{tag}-x86_64.exe`, the home header can show an Update card; About can start download + `--update` install.

## Local test (no tag)

Build and run Release as usual; packing an installer is optional until you want to ship.

## Notes

- Compile-from-source on operator machines is **not** supported.
- Windows x64 is the primary release target.
- Code signing uses existing fork secrets when configured; unsigned builds are fine for internal DCS use.
