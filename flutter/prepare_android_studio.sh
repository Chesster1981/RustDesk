#!/usr/bin/env bash
# Prepare native Rust libs + Flutter bridge so you can Run from Android Studio.
# Open the `flutter/` folder in Android Studio after this succeeds.
#
# Usage:
#   ./flutter/prepare_android_studio.sh              # x86_64 (Studio emulator)
#   ./flutter/prepare_android_studio.sh arm64-v8a    # physical arm64 device
#   ./flutter/prepare_android_studio.sh all          # emulator + arm64
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/flutter"
ABI_ARG="${1:-x86_64}"

CARGO_NDK_VERSION="${CARGO_NDK_VERSION:-3.1.2}"
FLUTTER_RUST_BRIDGE_VERSION="${FLUTTER_RUST_BRIDGE_VERSION:-1.80.1}"
VCPKG_COMMIT_ID="${VCPKG_COMMIT_ID:-120deac3062162151622ca4860575a33844ba10b}"
SKIP_DEPS="${SKIP_DEPS:-0}"
SKIP_BRIDGE="${SKIP_BRIDGE:-0}"

detect_android_sdk() {
	if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
		echo "$ANDROID_HOME"
		return
	fi
	if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "$ANDROID_SDK_ROOT" ]; then
		echo "$ANDROID_SDK_ROOT"
		return
	fi
	# Default Android Studio locations
	for candidate in \
		"$HOME/Android/Sdk" \
		"$HOME/Library/Android/sdk" \
		"/usr/local/lib/android/sdk" \
		"$HOME/android-dev/Android/Sdk"; do
		if [ -d "$candidate" ]; then
			echo "$candidate"
			return
		fi
	done
	return 1
}

detect_ndk() {
	local sdk="$1"
	if [ -n "${ANDROID_NDK_HOME:-}" ] && [ -d "$ANDROID_NDK_HOME" ]; then
		echo "$ANDROID_NDK_HOME"
		return
	fi
	# Prefer NDK r28c (28.2.13676358) — same as CI
	for ver in 28.2.13676358 28.1.13356709 27.2.12479018 26.3.11579264; do
		if [ -d "$sdk/ndk/$ver" ]; then
			echo "$sdk/ndk/$ver"
			return
		fi
	done
	# Any installed NDK
	local latest
	latest="$(ls -1d "$sdk/ndk"/* 2>/dev/null | sort -V | tail -n 1 || true)"
	if [ -n "$latest" ] && [ -d "$latest" ]; then
		echo "$latest"
		return
	fi
	if [ -d "$sdk/ndk-bundle" ]; then
		echo "$sdk/ndk-bundle"
		return
	fi
	return 1
}

detect_flutter() {
	if command -v flutter >/dev/null 2>&1; then
		dirname "$(dirname "$(command -v flutter)")"
		return
	fi
	for candidate in \
		"$HOME/flutter" \
		"$HOME/development/flutter" \
		"$HOME/snap/flutter/common/flutter" \
		"$HOME/android-dev/flutter"; do
		if [ -x "$candidate/bin/flutter" ]; then
			echo "$candidate"
			return
		fi
	done
	return 1
}

if ! ANDROID_HOME="$(detect_android_sdk)"; then
	cat >&2 <<'EOF'
ERROR: Android SDK not found.

In Android Studio:
  Settings → Languages & Frameworks → Android SDK
  note the "Android SDK Location", then:

  export ANDROID_HOME="/path/from/studio"
EOF
	exit 1
fi
export ANDROID_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"

if ! ANDROID_NDK_HOME="$(detect_ndk "$ANDROID_HOME")"; then
	cat >&2 <<'EOF'
ERROR: Android NDK not found.

In Android Studio:
  Settings → Android SDK → SDK Tools
  enable "NDK (Side by side)" and "CMake", Apply.
  Prefer NDK 28.2.13676358 (r28c) to match CI.
EOF
	exit 1
fi
export ANDROID_NDK_HOME ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"

if ! FLUTTER_HOME="$(detect_flutter)"; then
	cat >&2 <<'EOF'
ERROR: Flutter SDK not found on PATH.

Install Flutter 3.24.5 (matches CI), or in Android Studio install the
Flutter plugin and set the Flutter SDK path, then ensure `flutter` is on PATH.
EOF
	exit 1
fi
export PATH="$FLUTTER_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

case "$ABI_ARG" in
x86_64 | emulator)
	ABIS=(x86_64)
	;;
arm64-v8a | arm64 | aarch64)
	ABIS=(arm64-v8a)
	;;
armeabi-v7a | arm)
	ABIS=(armeabi-v7a)
	;;
all)
	ABIS=(x86_64 arm64-v8a)
	;;
*)
	echo "Usage: $0 [x86_64|arm64-v8a|armeabi-v7a|all]" >&2
	exit 1
	;;
esac

echo "ANDROID_HOME=$ANDROID_HOME"
echo "ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
echo "FLUTTER_HOME=$FLUTTER_HOME"
echo "ABIs: ${ABIS[*]}"

# local.properties for Gradle / Android Studio
LOCAL_PROPS="$FLUTTER_DIR/android/local.properties"
{
	echo "sdk.dir=${ANDROID_HOME//\\/\\\\}"
	echo "flutter.sdk=${FLUTTER_HOME}"
	echo "flutter.versionName=1.4.9"
	echo "flutter.versionCode=67"
	echo "ndk.dir=${ANDROID_NDK_HOME}"
} >"$LOCAL_PROPS"
echo "==> Wrote $LOCAL_PROPS"

if [ -z "${VCPKG_ROOT:-}" ]; then
	export VCPKG_ROOT="${VCPKG_ROOT_OVERRIDE:-$HOME/vcpkg}"
fi
if [ ! -x "$VCPKG_ROOT/vcpkg" ]; then
	echo "==> Bootstrapping vcpkg at $VCPKG_ROOT"
	git clone https://github.com/microsoft/vcpkg "$VCPKG_ROOT"
	git -C "$VCPKG_ROOT" checkout "$VCPKG_COMMIT_ID"
	"$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
fi

cargo install cargo-ndk --version "$CARGO_NDK_VERSION" --locked

if [ "$SKIP_BRIDGE" != "1" ]; then
	echo "==> Generating flutter_rust_bridge bindings"
	cargo install flutter_rust_bridge_codegen --version "$FLUTTER_RUST_BRIDGE_VERSION" --features uuid --locked
	if grep -q '^  uni_links_desktop:' "$FLUTTER_DIR/pubspec.yaml"; then
		cp -f "$FLUTTER_DIR/pubspec.yaml" "$FLUTTER_DIR/pubspec.yaml.bak"
		# Desktop-only dependency breaks Android resolve.
		awk '{ if ($0 ~ /^  uni_links_desktop:/) sub(/^  /, "  #"); print }' \
			"$FLUTTER_DIR/pubspec.yaml.bak" > "$FLUTTER_DIR/pubspec.yaml"
	fi
	(cd "$FLUTTER_DIR" && flutter pub get)
	(cd "$ROOT_DIR" && ~/.cargo/bin/flutter_rust_bridge_codegen \
		--rust-input ./src/flutter_ffi.rs \
		--dart-output ./flutter/lib/generated_bridge.dart)
fi

abi_to_vcpkg() {
	case "$1" in
	x86_64) echo x86_64 ;;
	arm64-v8a) echo arm64-v8a ;;
	armeabi-v7a) echo armeabi-v7a ;;
	esac
}

abi_to_ndk_script() {
	case "$1" in
	x86_64) echo ndk_x64.sh ;;
	arm64-v8a) echo ndk_arm64.sh ;;
	armeabi-v7a) echo ndk_arm.sh ;;
	esac
}

abi_to_rust_target() {
	case "$1" in
	x86_64) echo x86_64-linux-android ;;
	arm64-v8a) echo aarch64-linux-android ;;
	armeabi-v7a) echo armv7-linux-androideabi ;;
	esac
}

abi_to_cxx_shared() {
	case "$1" in
	x86_64) echo x86_64-linux-android ;;
	arm64-v8a) echo aarch64-linux-android ;;
	armeabi-v7a) echo arm-linux-androideabi ;;
	esac
}

ndk_host_tag() {
	case "$(uname -s)" in
	Linux) echo linux-x86_64 ;;
	Darwin)
		if [ "$(uname -m)" = "arm64" ] && [ -d "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-arm64" ]; then
			echo darwin-arm64
		else
			echo darwin-x86_64
		fi
		;;
	*)
		echo "ERROR: unsupported host $(uname -s) — build native libs on Linux/macOS" >&2
		exit 1
		;;
	esac
}

HOST_TAG="$(ndk_host_tag)"

cd "$ROOT_DIR"
for abi in "${ABIS[@]}"; do
	target="$(abi_to_rust_target "$abi")"
	rustup target add "$target"

	if [ "$SKIP_DEPS" != "1" ]; then
		echo "==> vcpkg deps for $abi"
		"$FLUTTER_DIR/build_android_deps.sh" "$(abi_to_vcpkg "$abi")"
	fi

	echo "==> Building librustdesk.so ($abi)"
	"$FLUTTER_DIR/$(abi_to_ndk_script "$abi")"
	outdir="$FLUTTER_DIR/android/app/src/main/jniLibs/$abi"
	mkdir -p "$outdir"
	cp -f "$ROOT_DIR/target/$target/release/liblibrustdesk.so" "$outdir/librustdesk.so"
	cp -f "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${HOST_TAG}/sysroot/usr/lib/$(abi_to_cxx_shared "$abi")/libc++_shared.so" \
		"$outdir/"
	echo "    -> $outdir/librustdesk.so"
done

cat <<EOF

Native build ready for Android Studio.

The emulator has no RustDesk until you install it. With the AVD running:

  $FLUTTER_DIR/install_android_emulator.sh

Or in Android Studio:
  1. File → Open → $FLUTTER_DIR  (the flutter/ folder, not repo root)
  2. Select the running AVD → Run ▶️ (flutter_hbb / main.dart)

Re-run this script after Rust/FFI changes:
  $0 ${ABI_ARG}

Environment tip — add to ~/.bashrc / ~/.zshrc:
  export ANDROID_HOME="$ANDROID_HOME"
  export ANDROID_NDK_HOME="$ANDROID_NDK_HOME"
  export VCPKG_ROOT="$VCPKG_ROOT"
  export PATH="$FLUTTER_HOME/bin:\$PATH"
EOF
