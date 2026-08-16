#!/usr/bin/env bash
# Build a debug APK (x86_64) and install it on the connected emulator/device.
# Prerequisites: emulator running in Android Studio + native libs prepared.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/flutter"
MODE="${MODE:-debug}"
PREPARE="${PREPARE:-1}"

detect_android_sdk() {
	if [ -n "${ANDROID_HOME:-}" ] && [ -d "$ANDROID_HOME" ]; then
		echo "$ANDROID_HOME"
		return
	fi
	local win_local="${LOCALAPPDATA:-}"
	win_local="${win_local//\\//}"
	for candidate in \
		"${win_local:+$win_local/Android/Sdk}" \
		"$HOME/AppData/Local/Android/Sdk" \
		"/c/Users/${USER:-$USERNAME}/AppData/Local/Android/Sdk" \
		"$HOME/Android/Sdk" \
		"$HOME/Library/Android/sdk"; do
		[ -n "$candidate" ] || continue
		if [ -d "$candidate" ]; then
			echo "$candidate"
			return
		fi
	done
	return 1
}

if ! ANDROID_HOME="$(detect_android_sdk)"; then
	cat >&2 <<'EOF'
ERROR: ANDROID_HOME not found.

On Windows (Git Bash), typically:
  export ANDROID_HOME="$LOCALAPPDATA/Android/Sdk"
  # or:
  export ANDROID_HOME="/c/Users/$USER/AppData/Local/Android/Sdk"
EOF
	exit 1
fi
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/platform-tools:${FLUTTER_HOME:-}/bin:$PATH"

if ! command -v adb >/dev/null 2>&1; then
	echo "ERROR: adb not found under $ANDROID_HOME/platform-tools" >&2
	exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
	echo "ERROR: flutter not on PATH — install Flutter 3.24.5 or set FLUTTER_HOME" >&2
	exit 1
fi

echo "==> Connected devices"
adb devices -l
if ! adb devices | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
	cat >&2 <<'EOF'
ERROR: no emulator/device in "device" state.

Start an AVD in Android Studio (Device Manager → ▶️), then re-run:
  ./flutter/install_android_emulator.sh
EOF
	exit 1
fi

JNI="$FLUTTER_DIR/android/app/src/main/jniLibs/x86_64/librustdesk.so"
if [ ! -f "$JNI" ]; then
	if [ "$PREPARE" = "1" ]; then
		echo "==> Missing jniLibs — running prepare_android_studio.sh x86_64"
		"$FLUTTER_DIR/prepare_android_studio.sh" x86_64
	else
		echo "ERROR: $JNI missing — run ./flutter/prepare_android_studio.sh x86_64 first" >&2
		exit 1
	fi
fi

# Debug builds do not need the release keystore.
GRADLE="$FLUTTER_DIR/android/app/build.gradle"
RESTORE_GRADLE=0
if [ "$MODE" != "release" ] && grep -q 'signingConfig signingConfigs.release' "$GRADLE"; then
	cp -f "$GRADLE" "$GRADLE.install-bak"
	sed -i.bak-tmp 's/signingConfig signingConfigs.release/signingConfig signingConfigs.debug/g' "$GRADLE" 2>/dev/null \
		|| sed -i '' 's/signingConfig signingConfigs.release/signingConfig signingConfigs.debug/g' "$GRADLE"
	rm -f "$GRADLE.bak-tmp"
	RESTORE_GRADLE=1
fi
restore_gradle() {
	if [ "$RESTORE_GRADLE" = "1" ] && [ -f "$GRADLE.install-bak" ]; then
		mv -f "$GRADLE.install-bak" "$GRADLE"
	fi
}
trap restore_gradle EXIT

cd "$FLUTTER_DIR"
echo "==> flutter build apk (--$MODE, android-x64)"
flutter build apk --"$MODE" --target-platform android-x64 --split-per-abi

APK="$FLUTTER_DIR/build/app/outputs/flutter-apk/app-x86_64-${MODE}.apk"
if [ ! -f "$APK" ]; then
	# Fallback name used by some Flutter versions
	APK="$FLUTTER_DIR/build/app/outputs/flutter-apk/app-${MODE}.apk"
fi
if [ ! -f "$APK" ]; then
	echo "ERROR: APK not found under build/app/outputs/flutter-apk/" >&2
	ls -la "$FLUTTER_DIR/build/app/outputs/flutter-apk/" >&2 || true
	exit 1
fi

echo "==> Installing $APK"
adb install -r "$APK"

echo "==> Launching com.carriez.flutter_hbb"
adb shell am start -n com.carriez.flutter_hbb/.MainActivity >/dev/null 2>&1 \
	|| adb shell monkey -p com.carriez.flutter_hbb -c android.intent.category.LAUNCHER 1 >/dev/null

echo
echo "RustDesk should now appear on the emulator (package: com.carriez.flutter_hbb)."
echo "Or in Android Studio: Open flutter/ → select the AVD → Run ▶️"
