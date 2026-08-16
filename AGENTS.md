# RustDesk Guide

## Project Layout

### Directory Structure
* `src/` Rust app
* `src/server/` audio / clipboard / input / video / network
* `src/platform/` platform-specific code
* `src/ui/` legacy Sciter UI (deprecated)
* `flutter/` current UI
* `libs/hbb_common/` config / proto / shared utils
* `libs/scrap/` screen capture
* `libs/enigo/` input control
* `libs/clipboard/` clipboard
* `libs/hbb_common/src/config.rs` all options

### Key Components
- **Remote Desktop Protocol**: Custom protocol implemented in `src/rendezvous_mediator.rs` for communicating with rustdesk-server
- **Screen Capture**: Platform-specific screen capture in `libs/scrap/`
- **Input Handling**: Cross-platform input simulation in `libs/enigo/`
- **Audio/Video Services**: Real-time audio/video streaming in `src/server/`
- **File Transfer**: Secure file transfer implementation in `libs/hbb_common/`

### UI Architecture
- **Legacy UI**: Sciter-based (deprecated) - files in `src/ui/`
- **Modern UI**: Flutter-based - files in `flutter/`
  - Desktop: `flutter/lib/desktop/`
  - Mobile: `flutter/lib/mobile/`
  - Shared: `flutter/lib/common/` and `flutter/lib/models/`

## Rust Rules

* Avoid `unwrap()` / `expect()` in production code.
* Exceptions:

  * tests;
  * lock acquisition where failure means poisoning, not normal control flow.
* Otherwise prefer `Result` + `?` or explicit handling.
* Do not ignore errors silently.
* Avoid unnecessary `.clone()`.
* Prefer borrowing when practical.
* Do not add dependencies unless needed.
* Keep code simple and idiomatic.

## Tokio Rules

* Assume a Tokio runtime already exists.
* Never create nested runtimes.
* Never call `Runtime::block_on()` inside Tokio / async code.
* Do not hide runtime creation inside helpers or libraries.
* Do not hold locks across `.await`.
* Prefer `.await`, `tokio::spawn`, channels.
* Use `spawn_blocking` or dedicated threads for blocking work.
* Do not use `std::thread::sleep()` in async code.

## Editing Hygiene

* Change only what is required.
* Prefer the smallest valid diff.
* Do not refactor unrelated code.
* Do not make formatting-only changes.
* Keep naming/style consistent with nearby code.

### Comments

* Keep them short: one line by default, three at most.
* Say **why**, never what. If the code already says it, delete the comment.
* Do not document rejected alternatives, past bugs, measurements, or how you arrived at the code. That belongs in the commit message or the PR.
* A comment must never be longer than the code it describes.
* Applies to YAML, shell and Python too, not just Rust.

### Be minimally invasive

* Prefer purely additive changes: layer new (`#[cfg]`-gated) blocks or new functions around existing code instead of restructuring it. The ideal diff for a fix adds lines and modifies/deletes none.
* Do not extract or reshape existing code just to enable your new code; look for a mechanism that leaves existing lines untouched (e.g. hide/show an existing object instead of refactoring its construction into a helper for rebuilding).
* Put new logic in self-contained functions in the module it belongs to (platform-specific logic in `src/platform/`, with `use` inside the function body to avoid churning shared import blocks). Call sites in shared files (`src/tray.rs`, `src/core_main.rs`, `src/server/connection.rs`, …) should be thin one-line hooks.

## Localization (`src/lang/*.rs`)

Each file is a `HashMap<key, translation>`. Layout:

* `template.rs` is the master list of every key. **Never edit it** as part of translation work.
* `en.rs` holds only the keys whose English display text differs from the key itself.
* Every other file (`de.rs`, `fr.rs`, …) carries the full key set; an untranslated entry has an empty value: `("key", "")`.

### Finding the English source for a key

When filling an empty entry, determine the source English text with this rule:

* If `key` exists in `en.rs` **with a non-empty value**, that value is the source text (look it up in `en.rs`).
* Otherwise the **key string itself is the source text** (the key is already plain English).

Then translate that source into the file's target language (infer the language from the file's existing non-empty entries / filename).

### Translation hygiene

* Only fill empty values. Never change keys, and never touch existing non-empty translations.
* Preserve placeholders (`{}`) and escape sequences (`\n`, `\"`) exactly as in the source.
* Do not translate brand or technical tokens: `RustDesk`, `Socks5`, `TLS`, `UAC`, `Wayland`, `X11`, `TCP`, `UDP`, `2FA`, `RDP`, `D3D`, etc.
* Copy URL values (e.g. `doc_*` keys) verbatim from `en.rs`.

### Adding new keys (feature work)

* New English-text keys use sentence case, not Title Case: `Use ID whitelisting`, **not** `Use ID Whitelisting`. Acronyms (ID, IP, 2FA…) stay uppercase. Legacy Title-Case keys (e.g. `Use IP Whitelisting`) stay as-is — do not rename them.
* Since the key itself is the English display text, a sentence-case key usually needs **no** `en.rs` entry; add one only when the display text must differ from the key (e.g. `*_tip` keys).
* Append each new key to `template.rs` (with `""`) and to every `src/lang/*.rs` file (translated, or `""` if unsure), at the end of the list.

## Cursor Cloud specific instructions

### Toolchain locations (installed in this VM)
* Flutter 3.24.5 → `~/flutter/bin`; Android SDK → `~/android-sdk` (`ANDROID_HOME`/`ANDROID_SDK_ROOT`); JDK 17 → `/usr/lib/jvm/java-17-openjdk-amd64`; vcpkg → `~/vcpkg` (`VCPKG_ROOT`); `cargo-expand` + `flutter_rust_bridge_codegen` in `~/.cargo/bin`.
* Add to PATH: `~/flutter/bin`, `~/android-sdk/cmdline-tools/latest/bin`, `~/android-sdk/platform-tools`, `~/android-sdk/emulator`.
* Gradle 7.6.4 needs JDK 17, not the default JDK 21 — set once with `flutter config --jdk-dir /usr/lib/jvm/java-17-openjdk-amd64`.
* vcpkg must build with gcc: run `vcpkg install ...` with `CC=gcc CXX=g++` (default `cc`/`c++` are clang here and fail `-lstdc++`).

### Android emulator (no nested KVM)
* `/dev/kvm` exists but a KVM-accelerated guest makes no progress in this VM. Run software-mode only: `emulator -avd rustdesk -accel off -gpu swiftshader_indirect -no-snapshot -no-audio -no-boot-anim -no-window`. First `sudo chmod 666 /dev/kvm` if `accel-check` complains.
* Cold boot ≈ 8 min; `System UI/Process isn't responding` ANRs are cosmetic (slow TCG). Debug Flutter builds render the first frame very slowly — screencap can stay black for a few minutes before the UI appears. For real speed use a physical device or a KVM-capable host.

### Fast Android UI iteration without cross-compiling Rust
The heavy part of the Android build is the Rust native lib + FFI bridge; the UI is all Flutter/Dart. To iterate quickly, reuse the prebuilt native libs from an official release APK whose version matches the repo:
1. Extract into `flutter/android/app/src/main/jniLibs/x86_64/`: both `librustdesk.so` **and** `libc++_shared.so` (missing libc++ → `UnsatisfiedLinkError` at startup).
2. Generate the FFI bridge once (needs the desktop Rust env + `VCPKG_ROOT`): `flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h`.
3. `cd flutter && flutter pub get && flutter build apk --debug --target-platform android-x64` (or `flutter run -d emulator-5554` for hot reload).
* `flutter/lib/generated_bridge.dart` and `jniLibs/*.so` are gitignored (generated/local) — do not commit them.
