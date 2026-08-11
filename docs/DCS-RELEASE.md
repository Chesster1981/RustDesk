# DCS Norway Remote Desktop Client — releases & updates

Operators get updates from **GitHub Releases** (pre-built `.exe`), not by compiling source on their PCs.

## Publish a new build

1. Bump the version in source so clients detect “newer”:
   - [`src/version.rs`](../src/version.rs) (`VERSION`)
   - [`Cargo.toml`](../Cargo.toml) / [`libs/portable/Cargo.toml`](../libs/portable/Cargo.toml)
   - Default `VERSION` in [`.github/workflows/flutter-build.yml`](../.github/workflows/flutter-build.yml) (optional; tag override is preferred)
2. Commit and push to the branding branch.
3. Create and push a **tag** matching the version string used in asset names, e.g.:
   - `1.4.10`
   - `1.4.9-2`  
   Prefer tags **without** a leading `v` so updater filenames stay simple (`rustdesk-1.4.10-x86_64.exe`).
4. Start the Windows build:
   - **Preferred while the workflow lives only on the branding branch:**  
     Actions → **DCS Windows Release** → Run workflow (branch = branding branch) → set `release_tag` to `1.4.10`.  
     Or: `gh workflow run "DCS Windows Release" --ref <branding-branch> -f release_tag=1.4.10`
   - **Automatic on tag push** works only after this workflow file exists on the repo **default** branch (GitHub limitation).
5. Wait for workflow **DCS Windows Release** (`.github/workflows/dcs-windows-release.yml`).
   It builds **Windows x64 only** (`windows-only: true`) so other platforms cannot block the installer.
6. On the GitHub Release for that tag, confirm assets:
   - `rustdesk-{tag}-x86_64.exe` — used by in-app updater
   - `DCS-Norway-RDC-{version}-x86_64-install.exe` — human-friendly alias  
   Release is marked **non-prerelease** so clients can find it.

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
