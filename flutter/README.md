# flutter_hbb

Flutter UI for RustDesk (desktop + mobile).

## Android Studio (recommended for Android)

RustDesk Android is Flutter + a native Rust library (`librustdesk.so`). Android Studio
runs the Flutter/Android side; you must build the Rust library first.

### 1. SDK tools in Android Studio

**Settings → Languages & Frameworks → Android SDK**

- SDK Platforms: **Android 14.0 (API 34)**
- SDK Tools:
  - Android SDK Build-Tools
  - NDK (Side by side) — prefer **28.2.13676358** (r28c, same as CI)
  - Android Emulator
  - Android SDK Platform-Tools
  - CMake

Note the **Android SDK Location** (usually `~/Android/Sdk`).

Also install the **Flutter** and **Dart** plugins, and Flutter SDK **3.24.5**.

### 2. Emulator

**Device Manager → Create Device** — Pixel 6 (or similar), system image
**Google APIs x86_64 / API 34**, then start the AVD.

### 3. Build native libs (once / after Rust changes)

From the repo root (requires Rust, `VCPKG_ROOT`, and NDK from Studio):

```sh
export ANDROID_HOME="$HOME/Android/Sdk"   # or path from Studio
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"
export VCPKG_ROOT="$HOME/vcpkg"           # bootstrap if needed

./flutter/prepare_android_studio.sh x86_64   # Studio emulator
# ./flutter/prepare_android_studio.sh arm64-v8a  # physical device
# ./flutter/prepare_android_studio.sh all
```

This writes `flutter/android/local.properties`, builds `jniLibs/`, and generates
the Flutter Rust bridge.

Optional helper if Flutter is not installed yet:

```sh
./flutter/setup_android_dev.sh
source ~/android-dev/env.sh
```

### 4. Open and Run

1. Android Studio → **File → Open** → select the `flutter/` directory  
2. Set Flutter SDK path under **Settings → Flutter**  
3. Select your AVD → **Run** ▶️ (`com.carriez.flutter_hbb`)

After changing Rust or FFI code, re-run `prepare_android_studio.sh` before Run.
