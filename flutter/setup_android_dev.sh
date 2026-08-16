#!/usr/bin/env bash
# Optional: install Flutter + confirm Android Studio SDK/NDK for RustDesk.
# Prefer Android Studio for the emulator (Device Manager). This script only
# fills gaps (Flutter SDK, cmdline tools) and writes ~/android-dev/env.sh.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.24.5}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${ANDROID_DEV_HOME:-$HOME/android-dev}"
FLUTTER_HOME="${FLUTTER_HOME:-$TOOLS_DIR/flutter}"

detect_studio_sdk() {
	if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
		echo "$ANDROID_HOME"
		return
	fi
	for candidate in \
		"$HOME/Android/Sdk" \
		"$HOME/Library/Android/sdk" \
		"$TOOLS_DIR/Android/Sdk"; do
		if [ -d "$candidate" ]; then
			echo "$candidate"
			return
		fi
	done
	return 1
}

mkdir -p "$TOOLS_DIR"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
	echo "==> Installing Flutter ${FLUTTER_VERSION} to $FLUTTER_HOME"
	curl -fsSL \
		"https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
		-o /tmp/flutter.tar.xz
	rm -rf "$FLUTTER_HOME"
	tar -xJf /tmp/flutter.tar.xz -C "$TOOLS_DIR"
	rm -f /tmp/flutter.tar.xz
	PATCH="$ROOT_DIR/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"
	if [ -f "$PATCH" ] && [ "$FLUTTER_VERSION" = "3.24.5" ]; then
		(cd "$FLUTTER_HOME" && git apply "$PATCH") || true
	fi
fi

if ! ANDROID_HOME="$(detect_studio_sdk)"; then
	cat >&2 <<'EOF'
ERROR: No Android SDK found.

Open Android Studio → More Actions → SDK Manager (or Settings → Android SDK)
and install:
  - Android SDK Platform 34
  - Android SDK Build-Tools
  - NDK (Side by side), preferably 28.2.13676358
  - Android Emulator
  - at least one system image (Google APIs x86_64 API 34)

Then re-run this script, or set ANDROID_HOME to the SDK path shown in Studio.
EOF
	exit 1
fi

NDK_HOME=""
if [ -n "${ANDROID_NDK_HOME:-}" ] && [ -d "$ANDROID_NDK_HOME" ]; then
	NDK_HOME="$ANDROID_NDK_HOME"
else
	for ver in 28.2.13676358 28.1.13356709 27.2.12479018; do
		if [ -d "$ANDROID_HOME/ndk/$ver" ]; then
			NDK_HOME="$ANDROID_HOME/ndk/$ver"
			break
		fi
	done
	if [ -z "$NDK_HOME" ]; then
		NDK_HOME="$(ls -1d "$ANDROID_HOME/ndk"/* 2>/dev/null | sort -V | tail -n 1 || true)"
	fi
fi

if [ -z "$NDK_HOME" ] || [ ! -d "$NDK_HOME" ]; then
	echo "ERROR: NDK missing under $ANDROID_HOME/ndk — install via Android Studio SDK Tools." >&2
	exit 1
fi

ENV_FILE="$TOOLS_DIR/env.sh"
cat >"$ENV_FILE" <<EOF
# Generated for Android Studio + RustDesk. Source before CLI builds.
export ANDROID_HOME="$ANDROID_HOME"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="$NDK_HOME"
export ANDROID_NDK_ROOT="$NDK_HOME"
export FLUTTER_HOME="$FLUTTER_HOME"
export PATH="\$FLUTTER_HOME/bin:\$ANDROID_HOME/platform-tools:\$PATH"
export JAVA_HOME="\${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
EOF

# shellcheck source=/dev/null
source "$ENV_FILE"
flutter config --no-analytics >/dev/null || true
flutter doctor -v || true

cat <<EOF

Ready. Next:

  1. source $ENV_FILE
  2. $ROOT_DIR/flutter/prepare_android_studio.sh x86_64
  3. Android Studio → Open → $ROOT_DIR/flutter
  4. Device Manager → start your AVD → Run ▶️

Use the Studio emulator (Device Manager), not a separate CLI emulator.
EOF
