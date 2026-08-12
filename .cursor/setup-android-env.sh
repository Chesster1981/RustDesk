#!/usr/bin/env bash
# Install Android SDK/NDK, Flutter, AVD, and related RustDesk Android build tools.
# Idempotent — safe to re-run from Cursor environment install.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/env-android.sh"

log() { printf '==> %s\n' "$*"; }

ensure_kvm_access() {
	if [[ -e /dev/kvm ]]; then
		sudo chmod 666 /dev/kvm 2>/dev/null || true
	fi
}

install_apt_deps() {
	log "Installing apt packages"
	export DEBIAN_FRONTEND=noninteractive
	sudo apt-get update -qq
	sudo apt-get install -y -qq \
		clang \
		cmake \
		curl \
		git \
		g++ \
		libclang-dev \
		libssl-dev \
		libunwind-dev \
		nasm \
		ninja-build \
		openjdk-17-jdk-headless \
		pkg-config \
		unzip \
		wget \
		xz-utils \
		zip \
		libpulse0 \
		libnss3 \
		libxcomposite1 \
		libxdamage1 \
		libxi6 \
		libxtst6 \
		libglu1-mesa \
		qemu-kvm \
		>/dev/null
}

install_flutter() {
	local version="3.24.5"
	if [[ -x "$FLUTTER_HOME/bin/flutter" ]]; then
		local have
		have="$("$FLUTTER_HOME/bin/flutter" --version 2>/dev/null | head -1 || true)"
		if echo "$have" | grep -q "$version"; then
			log "Flutter $version already installed"
			return 0
		fi
	fi

	log "Installing Flutter $version"
	rm -rf "$FLUTTER_HOME"
	git clone --depth 1 --branch "$version" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
	"$FLUTTER_HOME/bin/flutter" config --no-analytics
	"$FLUTTER_HOME/bin/flutter" precache --android
	"$FLUTTER_HOME/bin/dart" --disable-analytics >/dev/null 2>&1 || true

	# Match CI: optional dropdown_menu patch for 3.24.5
	local patch="$SCRIPT_DIR/../.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"
	if [[ -f "$patch" ]]; then
		log "Applying Flutter dropdown_menu patch"
		(cd "$FLUTTER_HOME" && git apply "$patch") || log "Flutter patch already applied or skipped"
	fi
}

install_android_sdk() {
	mkdir -p "$ANDROID_HOME/cmdline-tools"
	if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
		log "Installing Android cmdline-tools"
		local zip="/tmp/cmdline-tools.zip"
		# pin a known-good cmdline-tools build
		curl -fsSL -o "$zip" \
			https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
		rm -rf /tmp/cmdline-tools-extract
		mkdir -p /tmp/cmdline-tools-extract
		unzip -q "$zip" -d /tmp/cmdline-tools-extract
		rm -rf "$ANDROID_HOME/cmdline-tools/latest"
		mkdir -p "$ANDROID_HOME/cmdline-tools"
		mv /tmp/cmdline-tools-extract/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
		rm -f "$zip"
	else
		log "Android cmdline-tools already installed"
	fi

	yes | sdkmanager --licenses >/dev/null || true

	log "Installing Android SDK packages (platform 34, NDK r28c, emulator)"
	sdkmanager --install \
		"platform-tools" \
		"platforms;android-34" \
		"build-tools;34.0.0" \
		"ndk;28.2.13676358" \
		"emulator" \
		"system-images;android-34;google_apis;x86_64"
}

create_avd() {
	if avdmanager list avd 2>/dev/null | grep -q "Name: $ANDROID_AVD_NAME"; then
		log "AVD $ANDROID_AVD_NAME already exists"
	else
		log "Creating AVD $ANDROID_AVD_NAME"
		echo no | avdmanager create avd \
			--name "$ANDROID_AVD_NAME" \
			--package "system-images;android-34;google_apis;x86_64" \
			--device "pixel_6" \
			--force
	fi

	# Cloud VMs: nested KVM often hangs the guest; scripts default to -accel off.
	# Cold-boot flags avoid stuck downloadable-snapshot first boots.
	local cfg="$HOME/.android/avd/${ANDROID_AVD_NAME}.avd/config.ini"
	if [[ -f "$cfg" ]]; then
		python3 - "$cfg" <<'PY'
import sys
from pathlib import Path
cfg = Path(sys.argv[1])
overrides = {
    "hw.keyboard": "yes",
    "hw.gpu.enabled": "yes",
    "hw.gpu.mode": "swiftshader_indirect",
    "hw.ramSize": "3072",
    "hw.cpu.ncore": "4",
    "disk.dataPartition.size": "4G",
    "disk.dataPartition.path": "userdata-qemu.img",
    "fastboot.forceColdBoot": "yes",
    "fastboot.forceFastBoot": "no",
    "firstboot.bootFromDownloadableSnapshot": "no",
    "firstboot.bootFromLocalSnapshot": "no",
    "firstboot.saveToLocalSnapshot": "no",
}
lines, seen = [], set()
for line in cfg.read_text().splitlines():
    if "=" not in line:
        lines.append(line)
        continue
    key = line.split("=", 1)[0].strip()
    if key in overrides:
        if key in seen:
            continue
        lines.append(f"{key} = {overrides[key]}")
        seen.add(key)
    else:
        lines.append(line)
for key, value in overrides.items():
    if key not in seen:
        lines.append(f"{key} = {value}")
cfg.write_text("\n".join(lines) + "\n")
PY
	fi
}

install_vcpkg() {
	local commit="120deac3062162151622ca4860575a33844ba10b"
	if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
		log "Installing vcpkg"
		git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
		(cd "$VCPKG_ROOT" && git checkout "$commit" && ./bootstrap-vcpkg.sh -disableMetrics)
	else
		log "vcpkg already installed"
		(cd "$VCPKG_ROOT" && git fetch --quiet && git checkout "$commit" && ./bootstrap-vcpkg.sh -disableMetrics) || true
	fi
}

install_rust_android() {
	log "Installing Rust Android targets + cargo-ndk"
	rustup target add \
		x86_64-linux-android \
		aarch64-linux-android \
		armv7-linux-androideabi \
		i686-linux-android
	cargo install cargo-ndk --version 3.1.2 --locked 2>/dev/null || \
		cargo install cargo-ndk --version 3.1.2 --locked
}

write_profile_snippet() {
	local snippet="/etc/profile.d/rustdesk-android.sh"
	log "Writing $snippet"
	sudo tee "$snippet" >/dev/null <<EOF
# RustDesk Android / Flutter toolchain (Cursor cloud agent)
if [ -f "\$HOME/.cursor-android-env.sh" ]; then
  . "\$HOME/.cursor-android-env.sh"
fi
EOF
	cp "$SCRIPT_DIR/env-android.sh" "$HOME/.cursor-android-env.sh"
	# Also ensure interactive shells pick it up
	if ! grep -q 'cursor-android-env' "$HOME/.bashrc" 2>/dev/null; then
		echo '[ -f "$HOME/.cursor-android-env.sh" ] && . "$HOME/.cursor-android-env.sh"' >>"$HOME/.bashrc"
	fi
}

smoke_check() {
	log "Smoke check"
	java -version
	flutter --version | head -3
	sdkmanager --version
	adb version | head -1
	emulator -list-avds
	test -d "$ANDROID_NDK_HOME"
	log "Android environment setup complete"
}

main() {
	ensure_kvm_access
	install_apt_deps
	# Prefer JDK 17 for Android Gradle
	if [[ -d /usr/lib/jvm/java-17-openjdk-amd64 ]]; then
		export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
	fi
	# shellcheck source=/dev/null
	source "$SCRIPT_DIR/env-android.sh"
	install_flutter
	# shellcheck source=/dev/null
	source "$SCRIPT_DIR/env-android.sh"
	install_android_sdk
	create_avd
	install_vcpkg
	install_rust_android
	write_profile_snippet
	# shellcheck source=/dev/null
	source "$SCRIPT_DIR/env-android.sh"
	smoke_check
}

main "$@"
