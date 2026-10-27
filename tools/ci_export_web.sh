#!/bin/sh
# Export the Web preset with threads off. Needs the full templates archive.
set -eu
root="${RUNNER_TEMP:-/tmp}/godot-ci"
tpl="$HOME/.local/share/godot/export_templates/4.7.2.stable"
mkdir -p "$root" "$tpl"
curl -fsSL -o "$root/godot.zip" \
  "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"
unzip -q "$root/godot.zip" -d "$root"
bin="$root/Godot_v4.7.2-stable_linux.x86_64"
test -f "$bin"
chmod +x "$bin"
"$bin" --version
curl -fsSL -o "$root/templates.tpz" \
  "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
mkdir -p "$root/tpl"
unzip -qo "$root/templates.tpz" -d "$root/tpl" \
  templates/version.txt \
  templates/web_nothreads_release.zip \
  templates/web_nothreads_debug.zip
cp -a "$root/tpl/templates/." "$tpl/"
mkdir -p build/web
"$bin" --headless --path . --export-release "Web" "$PWD/build/web/index.html"
test -f build/web/index.wasm
test -f build/web/index.pck
