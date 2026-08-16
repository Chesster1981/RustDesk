#!/usr/bin/env bash
# Build RustDesk Android APK for x86_64 emulator and install it.
# Mirrors CI steps for the x86_64-linux-android target (debug signing).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/.cursor/env-android.sh"

MODE="${MODE:-debug}"
SKIP_NATIVE="${SKIP_NATIVE:-0}"
SKIP_BRIDGE="${SKIP_BRIDGE:-0}"
INSTALL="${INSTALL:-1}"

cd "$ROOT"

if [[ -z "${ANDROID_NDK_HOME:-}" || ! -d "$ANDROID_NDK_HOME" ]]; then
	echo "ERROR: ANDROID_NDK_HOME not set or missing" >&2
	exit 1
fi
if [[ -z "${VCPKG_ROOT:-}" || ! -x "$VCPKG_ROOT/vcpkg" ]]; then
	echo "ERROR: VCPKG_ROOT not set or vcpkg missing" >&2
	exit 1
fi

if [[ ! -f libs/hbb_common/Cargo.toml ]]; then
	echo "==> git submodule update --init --recursive"
	git submodule update --init --recursive
fi

ensure_bridge() {
	if [[ -f src/bridge_generated.rs && -f flutter/lib/generated_bridge.dart ]]; then
		echo "==> flutter_rust_bridge already generated"
		return 0
	fi
	echo "==> generating flutter_rust_bridge"
	cargo install cargo-expand --version 1.0.95 --locked
	cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked
	(
		cd flutter
		flutter pub get
	)
	mkdir -p flutter/macos/Runner flutter/ios/Runner
	flutter_rust_bridge_codegen \
		--rust-input ./src/flutter_ffi.rs \
		--dart-output ./flutter/lib/generated_bridge.dart \
		--c-output ./flutter/macos/Runner/bridge_generated.h
	cp ./flutter/macos/Runner/bridge_generated.h ./flutter/ios/Runner/bridge_generated.h
}

if [[ "$SKIP_BRIDGE" != "1" ]]; then
	ensure_bridge
fi

if [[ "$SKIP_NATIVE" != "1" ]]; then
	echo "==> vcpkg deps (x86_64)"
	./flutter/build_android_deps.sh x86_64

	echo "==> cargo-ndk (x86_64-linux-android)"
	rustup target add x86_64-linux-android
	./flutter/ndk_x64.sh

	mkdir -p ./flutter/android/app/src/main/jniLibs/x86_64
	cp ./target/x86_64-linux-android/release/liblibrustdesk.so \
		./flutter/android/app/src/main/jniLibs/x86_64/librustdesk.so
	cp "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/x86_64-linux-android/libc++_shared.so" \
		./flutter/android/app/src/main/jniLibs/x86_64/
fi

echo "==> flutter pub get"
(
	cd flutter
	flutter pub get
)

# CI uses debug signing for unsigned local builds; restore file afterwards
GRADLE=flutter/android/app/build.gradle
GRADLE_BAK="$(mktemp)"
cp "$GRADLE" "$GRADLE_BAK"
sed -i 's/signingConfigs.release/signingConfigs.debug/g' "$GRADLE"
trap 'cp "$GRADLE_BAK" "$GRADLE"; rm -f "$GRADLE_BAK"' EXIT

echo "==> flutter build apk ($MODE, android-x64)"
(
	cd flutter
	flutter build apk --"$MODE" --target-platform android-x64 --split-per-abi
)

APK="$(find flutter/build/app/outputs/flutter-apk -name '*x86_64*.apk' | head -1)"
if [[ -z "$APK" ]]; then
	APK="$(find flutter/build/app/outputs/flutter-apk -name '*.apk' | head -1)"
fi
echo "APK: $APK"

if [[ "$INSTALL" == "1" ]]; then
	"$ROOT/scripts/android/start-emulator.sh"
	adb install -r "$APK"
	adb shell am start -n com.carriez.flutter_hbb/.MainActivity || true
	echo "Installed and launched"
fi
