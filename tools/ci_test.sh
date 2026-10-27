#!/bin/sh
# Download pinned Godot 4.7.2, import, and require failed=0.
# GitHub Actions runs this. Locally, tools/check.sh uses an installed editor.
set -eu
root="${RUNNER_TEMP:-/tmp}/godot-ci"
mkdir -p "$root"
curl -fsSL -o "$root/godot.zip" \
  "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"
unzip -q "$root/godot.zip" -d "$root"
bin="$root/Godot_v4.7.2-stable_linux.x86_64"
test -f "$bin"
chmod +x "$bin"
"$bin" --version
"$bin" --headless --path . --import --quit
log="${RUNNER_TEMP:-/tmp}/relay-breach-tests.txt"
"$bin" --headless --path . -s res://tests/run_tests.gd > "$log"
cat "$log"
grep -q "failed=0" "$log"
