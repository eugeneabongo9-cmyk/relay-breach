#!/bin/sh
# Local equivalent of .github/workflows/ci.yml test job.
set -eu
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import --quit
"$GODOT" --headless --path . -s res://tests/run_tests.gd | tee /tmp/relay-breach-tests.txt
grep -q "failed=0" /tmp/relay-breach-tests.txt
