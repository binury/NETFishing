#!/usr/bin/env bash
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-${HOME}/Android/Sdk}"
JAVA_HOME="${JAVA_HOME:-}"
INSTALL=0
AUTO=0
CMDLINE_TOOLS_ZIP="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
SDK_VERSION="33"
BUILDTOOLS_VERSION="34.0.0"

usage() {
  cat <<USAGE
Usage: scripts/setup_android_build.sh [options]

Options:
  --android-home PATH    Android SDK root (default: ${ANDROID_HOME})
  --java-home PATH       Java/JDK root (default: autodetect)
  --sdk-version N        Android SDK API level to ensure installed (default: ${SDK_VERSION})
  --build-tools N        Build Tools version to ensure installed (default: ${BUILDTOOLS_VERSION})
  --install              Attempt to install missing SDK components/JDK tools when possible
  --noninteractive       Run install steps without prompts
  --help                 Show this help

This script is a preflight helper for Godot Android export.
Without --install it only checks dependencies and prints exact next actions.
With --install it will:
  * attempt to install missing packages via sdkmanager (or guide you to setup)
  * optionally install JDK via system package manager when supported.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android-home)
      ANDROID_HOME="$2"; shift 2 ;;
    --java-home)
      JAVA_HOME="$2"; shift 2 ;;
    --sdk-version)
      SDK_VERSION="$2"; shift 2 ;;
    --build-tools)
      BUILDTOOLS_VERSION="$2"; shift 2 ;;
    --install)
      INSTALL=1; shift ;;
    --noninteractive)
      AUTO=1; shift ;;
    --help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2 ;;
  esac
done

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
PROJECT_VERSION="$(
  sed -n 's/^config\/version="\([^"]*\)"/\1/p' "${PROJECT_ROOT}/project.godot"
)"
MISSING=0

print_status() { printf '%s %s\n' "[$1]" "$2"; }

check_dir() {
  local path="$1" label="$2"
  if [[ -d "$path" ]]; then
    print_status OK "${label}: ${path}"
  else
    print_status ERR "Missing ${label}: ${path}"
    MISSING=$((MISSING+1))
  fi
}

check_file() {
  local path="$1" label="$2"
  if [[ -x "$path" ]]; then
    print_status OK "${label}: ${path}"
  else
    print_status ERR "Missing ${label}: ${path}"
    MISSING=$((MISSING+1))
  fi
}

resolve_java_home() {
  local candidate=""
  if [[ -n "$JAVA_HOME" && -x "$JAVA_HOME/bin/java" ]]; then
    return 0
  fi

  if command -v java >/dev/null 2>&1; then
    candidate="$(readlink -f "$(command -v java)")"
    candidate="$(dirname "$(dirname "$candidate")")"
    if [[ -x "$candidate/bin/java" ]]; then
      JAVA_HOME="$candidate"
      return 0
    fi
  fi

  # Common Ubuntu/Debian/JDK locations
  for p in \
    /usr/lib/jvm/default-java \
    /usr/lib/jvm/java-17-openjdk-amd64 \
    /usr/lib/jvm/java-17-openjdk \
    /usr/lib/jvm/jdk-17* \
    /usr/lib/jvm/temurin-17*;
  do
    if [[ -e $p && -x "$p/bin/java" ]]; then
      JAVA_HOME="$p"
      return 0
    fi
  done
  return 1
}

check_java() {
  if resolve_java_home && [[ -x "$JAVA_HOME/bin/java" ]]; then
    print_status OK "Java binary: $JAVA_HOME/bin/java"
    check_file "$JAVA_HOME/bin/javac" "javac binary"
    check_file "$JAVA_HOME/bin/keytool" "keytool binary"
    "$JAVA_HOME/bin/java" -version 2>&1 | sed -n '1,2p'
    local java_ver
    java_ver=$("$JAVA_HOME/bin/java" -version 2>&1 | sed -n '1p')
    if [[ "$java_ver" =~ \"([0-9]+)\\. ]]; then
      local java_major="${BASH_REMATCH[1]}"
      if [[ "$java_major" != "17" ]]; then
        print_status WARN "Detected Java $java_major. Godot Android export is commonly validated with JDK 17."
      fi
    fi
  else
    print_status ERR "Java not found. Set JAVA_HOME to a JDK 17+ home or install one."
    MISSING=$((MISSING+1))
    JAVA_HOME=""
  fi
}

find_sdkmanager() {
  if [[ -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
    echo "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
    return
  fi
  if [[ -x "$ANDROID_HOME/cmdline-tools/bin/sdkmanager" ]]; then
    echo "$ANDROID_HOME/cmdline-tools/bin/sdkmanager"; return
  fi
  if [[ -x "$ANDROID_HOME/tools/bin/sdkmanager" ]]; then
    echo "$ANDROID_HOME/tools/bin/sdkmanager"; return
  fi
  if command -v sdkmanager >/dev/null 2>&1; then
    command -v sdkmanager
    return
  fi
  echo ""
}

sdkmanager_path="$(find_sdkmanager)"
TMP_CMDLINE_TOOLS_DIR=""

cleanup_tmpdir() {
  [[ -n "${TMP_CMDLINE_TOOLS_DIR:-}" && -d "$TMP_CMDLINE_TOOLS_DIR" ]] && rm -rf "$TMP_CMDLINE_TOOLS_DIR"
  TMP_CMDLINE_TOOLS_DIR=""
}

check_sdk_paths() {
  print_status INFO "ANDROID_HOME: ${ANDROID_HOME}"
  check_dir "$ANDROID_HOME" "Android SDK root"
  check_dir "$ANDROID_HOME/platform-tools" "platform-tools"
  check_file "$ANDROID_HOME/platform-tools/adb" "adb binary"

  if [[ -d "$ANDROID_HOME/build-tools/$BUILDTOOLS_VERSION" ]]; then
    print_status OK "build-tools ${BUILDTOOLS_VERSION}: present"
    check_file \
      "$ANDROID_HOME/build-tools/$BUILDTOOLS_VERSION/apksigner" \
      "apksigner"
  else
    print_status ERR "Missing build-tools version: ${BUILDTOOLS_VERSION}"
    MISSING=$((MISSING+1))
  fi

  if [[ -d "$ANDROID_HOME/platforms" ]]; then
    if ls "$ANDROID_HOME/platforms/android-${SDK_VERSION}" >/dev/null 2>&1; then
      print_status OK "platform ${SDK_VERSION}: present"
    else
      print_status ERR "Missing Android platform: android-${SDK_VERSION}"
      MISSING=$((MISSING+1))
    fi
  else
    print_status ERR "Missing platforms directory: $ANDROID_HOME/platforms"
    MISSING=$((MISSING+1))
  fi

  if [[ -x "$sdkmanager_path" ]]; then
    print_status OK "sdkmanager: ${sdkmanager_path}"
  else
    print_status ERR "sdkmanager not found in SDK or PATH"
    MISSING=$((MISSING+1))
  fi
}

install_jdk_hint() {
  local pm=0
  local -a elevate=()
  echo "Attempting automatic JDK install..."
  if command -v apt-get >/dev/null 2>&1; then
    pm="apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    pm="dnf"
  elif command -v pacman >/dev/null 2>&1; then
    pm="pacman"
  else
    echo "No supported package manager found (apt-get/dnf/pacman)."
    echo "Install JDK 17 manually, then rerun with --java-home set."
    return 1
  fi

  if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      echo "sudo not found; please run with root privileges for package install."
      return 1
    fi
    elevate=(sudo)
  fi

  if [[ "$pm" == "apt-get" ]]; then
    echo "apt-get install -y openjdk-17-jdk"
    if [[ $AUTO -eq 1 ]]; then
      "${elevate[@]}" apt-get update
      "${elevate[@]}" apt-get install -y openjdk-17-jdk
    else
      echo "Run as manual step first: sudo apt-get update && sudo apt-get install -y openjdk-17-jdk"
      return 1
    fi
  elif [[ "$pm" == "dnf" ]]; then
    echo "dnf install -y java-17-openjdk-devel"
    if [[ $AUTO -eq 1 ]]; then
      "${elevate[@]}" dnf install -y java-17-openjdk-devel
    else
      return 1
    fi
  else
    echo "pacman -S --noconfirm jdk17-openjdk"
    if [[ $AUTO -eq 1 ]]; then
      "${elevate[@]}" pacman -S --noconfirm jdk17-openjdk
    else
      return 1
    fi
  fi
}

install_cmdline_tools() {
  if [[ -x "$sdkmanager_path" ]]; then
    return 0
  fi

  echo "Downloading Android cmdline-tools to bootstrap sdkmanager..."
  TMP_CMDLINE_TOOLS_DIR=""
  TMP_CMDLINE_TOOLS_DIR="$(mktemp -d)"
  if [[ -z "$TMP_CMDLINE_TOOLS_DIR" ]]; then
    echo "Failed to create temporary directory."
    return 1
  fi
  trap cleanup_tmpdir RETURN

  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "curl/wget required to download cmdline-tools. Install one and rerun."
    return 1
  fi

  local zipfile="${TMP_CMDLINE_TOOLS_DIR}/cmdline-tools.zip"
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fL "$CMDLINE_TOOLS_ZIP" -o "$zipfile"; then
      echo "Failed to download cmdline-tools from $CMDLINE_TOOLS_ZIP"
      return 1
    fi
  else
    if ! wget -q "$CMDLINE_TOOLS_ZIP" -O "$zipfile"; then
      echo "Failed to download cmdline-tools from $CMDLINE_TOOLS_ZIP"
      return 1
    fi
  fi

  if [[ ! -s "$zipfile" ]]; then
    echo "Downloaded cmdline-tools archive is empty."
    return 1
  fi
  unzip -q "$zipfile" -d "$TMP_CMDLINE_TOOLS_DIR"
  if [[ ! -d "$TMP_CMDLINE_TOOLS_DIR/cmdline-tools" ]]; then
    echo "Downloaded archive did not contain expected cmdline-tools payload."
    return 1
  fi
  mkdir -p "$ANDROID_HOME" || {
    echo "Cannot create Android SDK root: $ANDROID_HOME"
    return 1
  }
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
  mv "$TMP_CMDLINE_TOOLS_DIR/cmdline-tools"/* "$ANDROID_HOME/cmdline-tools/latest/"
  echo "Installed SDK cmdline-tools to $ANDROID_HOME/cmdline-tools/latest"
  sdkmanager_path="$(find_sdkmanager)"
  return 0
}

install_sdk_components() {
  if [[ -z "$sdkmanager_path" ]]; then
    echo "Cannot install SDK packages without sdkmanager."
    return 1
  fi
  "$sdkmanager_path" --sdk_root="${ANDROID_HOME}" --list | sed -n '1,40p'
  echo "Installing required SDK components: platform-tools, platform-android-${SDK_VERSION}, build-tools-${BUILDTOOLS_VERSION}"
  if [[ $AUTO -eq 1 ]]; then
    yes | "$sdkmanager_path" --sdk_root="${ANDROID_HOME}" --install "platform-tools" "platforms;android-${SDK_VERSION}" "build-tools;${BUILDTOOLS_VERSION}"
  else
    echo "Run this manually after accepting licenses:"
    echo "  yes | \"${sdkmanager_path}\" --sdk_root=\"${ANDROID_HOME}\" --install \"platform-tools\" \"platforms;android-${SDK_VERSION}\" \"build-tools;${BUILDTOOLS_VERSION}\""
    return 1
  fi
}

check_editor_settings() {
  local editor_settings="$HOME/.config/godot/editor_settings-4.7.tres"
  print_status INFO "Checking editor settings: $editor_settings"
  if [[ -f "$editor_settings" ]]; then
    if rg -n 'export/android/android_sdk_path|export/android/java_sdk_path' "$editor_settings" >/dev/null 2>&1; then
      rg -n 'export/android/android_sdk_path|export/android/java_sdk_path' "$editor_settings"
    else
      print_status WARN "Editor export settings entries are missing for Android in this file"
      echo "  Set in editor: Export > Presets > Android:"
      echo "    android_sdk_path = ${ANDROID_HOME}"
      echo "    java_sdk_path = ${JAVA_HOME}"
    fi
  else
    print_status WARN "No editor settings file found at expected path: $editor_settings"
  fi
}

run_export_hint() {
  echo
  echo "Example export commands:"
  echo "  ${GODOT} --headless --path \"$PROJECT_ROOT\" --export-release \"Android\" builds/${PROJECT_VERSION}/android/NETfishing.apk"
  echo "  ${GODOT} --headless --path \"$PROJECT_ROOT\" --export-debug \"Android\" builds/android/NETfishing-debug.apk"
}

print_status INFO "Starting Android dependency preflight..."
check_java
check_sdk_paths
check_editor_settings

if [[ $MISSING -eq 0 ]]; then
  print_status OK "Dependency check passed."
  run_export_hint
  exit 0
fi

if [[ $INSTALL -eq 1 ]]; then
  echo
  print_status INFO "Attempting dependency install path..."
  if [[ \
    -z "$JAVA_HOME" \
    || ! -x "$JAVA_HOME/bin/java" \
    || ! -x "$JAVA_HOME/bin/javac" \
    || ! -x "$JAVA_HOME/bin/keytool" \
  ]]; then
    install_jdk_hint || true
  fi

  resolve_java_home || true
  check_java

  install_cmdline_tools || true
  sdkmanager_path="$(find_sdkmanager)"
  install_sdk_components || true

  MISSING=0
  check_java
  check_sdk_paths
  if [[ $MISSING -eq 0 ]]; then
    echo
    print_status OK "Dependencies fixed."
    run_export_hint
    exit 0
  fi
fi

print_status ERR "Dependency check failed with ${MISSING} issue(s)."
cat <<TIPS
Suggested manual recovery:
1) Install OpenJDK 17 JDK.
2) Install Android SDK command line tools and run:
   sdkmanager --sdk_root="${ANDROID_HOME}" --install "platform-tools" "platforms;android-${SDK_VERSION}" "build-tools;${BUILDTOOLS_VERSION}"
3) Set JAVA_HOME and ANDROID_HOME in your shell and Godot Exporter settings.
4) Re-run this script without --install (verification), then re-run Godot Android export.
TIPS

exit 3
