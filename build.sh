#!/usr/bin/env bash
# Builds Drift.app with swiftc, no Xcode project needed.
#   ./build.sh           build build/Drift.app for this Mac
#   ./build.sh install   build, then copy to ~/Applications
#   ./build.sh dist      build for Apple silicon and Intel, then zip to build/Drift.zip
#   ./build.sh test      run the logic checks
set -euo pipefail
cd "$(dirname "$0")"

MIN_MACOS="13.0"
APP="build/Drift.app"
SWIFT_FLAGS=(-O -swift-version 5)

target_for() {
  echo "$1-apple-macos${MIN_MACOS}"
}

# Each Tests/<suite>/ has a main.swift and a sources.txt listing the Sources it covers.
run_checks() {
  mkdir -p build
  for suite in Tests/*/; do
    local name
    name="$(basename "$suite")"
    local sources=()
    while IFS= read -r line; do [[ -n "$line" ]] && sources+=("$line"); done < "$suite/sources.txt"
    swiftc "${SWIFT_FLAGS[@]}" -target "$(target_for "$(uname -m)")" -o "build/checks-$name" \
      "${sources[@]}" "$suite/main.swift"
    "build/checks-$name"
  done
}

# Builds the app bundle for the given architectures, merged into one binary.
build_app() {
  local binary="$APP/Contents/MacOS/Drift"
  local slices=()
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS"
  for arch in "$@"; do
    swiftc "${SWIFT_FLAGS[@]}" -target "$(target_for "$arch")" -o "build/Drift-$arch" Sources/*.swift
    slices+=("build/Drift-$arch")
  done
  lipo -create "${slices[@]}" -output "$binary"
  rm -f "${slices[@]}"
  cp Resources/Info.plist "$APP/Contents/Info.plist"
  # An ad-hoc signature is enough for SMAppService to register a login item.
  codesign --force --sign - "$APP"
  echo "Built $APP for $* (macOS $MIN_MACOS+)"
}

install_app() {
  local dest="$HOME/Applications"
  mkdir -p "$dest"
  pkill -x Drift 2>/dev/null || true
  rm -rf "$dest/Drift.app"
  cp -R "$APP" "$dest/"
  echo "Installed $dest/Drift.app"
}

package_app() {
  rm -f build/Drift.zip
  ditto -c -k --keepParent "$APP" build/Drift.zip
  echo "Packaged build/Drift.zip"
}

case "${1:-build}" in
  build) build_app "$(uname -m)" ;;
  # Separate statements, not `&&`: set -e is ignored inside a function on the left of `&&`.
  install) build_app "$(uname -m)"; install_app ;;
  dist) build_app arm64 x86_64; package_app ;;
  test) run_checks ;;
  *) echo "usage: $0 [build|install|dist|test]" >&2; exit 64 ;;
esac
