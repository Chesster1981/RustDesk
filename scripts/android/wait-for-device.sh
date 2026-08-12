#!/usr/bin/env bash
# Wait until adb reports a fully-booted device.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/.cursor/env-android.sh"

TIMEOUT_SEC="${1:-180}"
deadline=$((SECONDS + TIMEOUT_SEC))

echo "Waiting for adb device (timeout ${TIMEOUT_SEC}s)..."
while ((SECONDS < deadline)); do
	if adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
		break
	fi
	sleep 2
done

if ! adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
	echo "ERROR: no adb device within ${TIMEOUT_SEC}s" >&2
	adb devices -l >&2 || true
	tail -n 40 "$HOME/android-emulator.log" 2>/dev/null >&2 || true
	exit 1
fi

echo "Waiting for sys.boot_completed..."
while ((SECONDS < deadline)); do
	booted="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
	if [[ "$booted" == "1" ]]; then
		adb devices -l
		echo "Device ready"
		exit 0
	fi
	sleep 2
done

echo "ERROR: device did not finish booting within ${TIMEOUT_SEC}s" >&2
exit 1
