#!/usr/bin/env bash
# Start the RustDesk Cursor AVD (headless, KVM when available).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/.cursor/env-android.sh"

if [[ -e /dev/kvm ]]; then
	sudo chmod 666 /dev/kvm 2>/dev/null || true
fi

if adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
	echo "Emulator/device already connected:"
	adb devices -l
	exit 0
fi

if ! emulator -list-avds | grep -qx "$ANDROID_AVD_NAME"; then
	echo "ERROR: AVD '$ANDROID_AVD_NAME' not found. Run .cursor/setup-android-env.sh first." >&2
	emulator -list-avds >&2 || true
	exit 1
fi

echo "Starting AVD: $ANDROID_AVD_NAME"
# -no-window works without a local GUI; DISPLAY is still used by some GPU paths
nohup emulator \
	-avd "$ANDROID_AVD_NAME" \
	-no-snapshot-save \
	-no-boot-anim \
	-gpu auto \
	-no-audio \
	-no-window \
	>"$HOME/android-emulator.log" 2>&1 &

echo "Emulator PID $! — log: $HOME/android-emulator.log"
exec "$ROOT/scripts/android/wait-for-device.sh"
