# Source this file to get Android/Flutter/RustDesk build paths.
# Idempotent: safe to source multiple times.

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.2.13676358}"
export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
export FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
export VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"
export ANDROID_AVD_NAME="${ANDROID_AVD_NAME:-rustdesk_api34}"

# cmdline-tools layout: $ANDROID_HOME/cmdline-tools/latest/bin
_android_path_add() {
	case ":$PATH:" in
	*":$1:"*) ;;
	*) PATH="$1:$PATH" ;;
	esac
}

_android_path_add "$JAVA_HOME/bin"
_android_path_add "$FLUTTER_HOME/bin"
_android_path_add "$ANDROID_HOME/cmdline-tools/latest/bin"
_android_path_add "$ANDROID_HOME/platform-tools"
_android_path_add "$ANDROID_HOME/emulator"
_android_path_add "$HOME/.cargo/bin"

export PATH
unset -f _android_path_add
