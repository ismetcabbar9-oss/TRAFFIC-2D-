#!/bin/bash
# Installs Godot 4.7.2-stable (Linux x86_64) to /usr/local/bin/godot and xvfb,
# so every new cloud session is ready for headless runs and screenshots.
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_BIN="/usr/local/bin/godot"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}"
ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

if ! { [ -x "$GODOT_BIN" ] && "$GODOT_BIN" --version 2>/dev/null | grep -q "^4.7.2.stable"; }; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/$ZIP" "$BASE_URL/$ZIP"
  curl -fsSL -o "$tmp/SHA512-SUMS.txt" "$BASE_URL/SHA512-SUMS.txt"
  (cd "$tmp" && grep " ${ZIP}\$" SHA512-SUMS.txt | sha512sum -c - >/dev/null)
  unzip -q -o "$tmp/$ZIP" -d "$tmp"
  install -m 755 "$tmp/Godot_v${GODOT_VERSION}_linux.x86_64" "$GODOT_BIN"
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y -qq xvfb >/dev/null
fi

# Populate the .godot import cache for the project.
if [ -f "${CLAUDE_PROJECT_DIR:-.}/project.godot" ]; then
  "$GODOT_BIN" --headless --path "${CLAUDE_PROJECT_DIR:-.}" --import >/dev/null 2>&1 || true
fi
