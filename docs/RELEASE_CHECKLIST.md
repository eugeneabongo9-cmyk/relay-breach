# Release checklist

Status from the session that produced 0.9.0. Evidence is a command or a file, not a vibe.

| Gate | Status | Evidence |
| --- | --- | --- |
| Clean import | PASS | `godot --headless --path . --import --quit` |
| Headless tests | PASS | `tests/run_tests.gd` → `RESULT passed=364 failed=0` |
| Web export | PASS (file exists) | `build/web/index.html`, threads off |
| Linux export | PASS (file exists) | `build/linux/relay-breach.x86_64` |
| Linux binary played on a desktop | UNVERIFIED | No display was used to play the packaged binary |
| Web build loads in a browser | PASS in the preview host | Bay visible, tutorial copy readable, W speed 7.4, A yaw +0.79, D yaw −0.84 |
| Tutorial + shield + extract loop | PASS headless | scripted smoke in `tests/run_tests.gd` |
| 60 fps at 1080p | UNVERIFIED | [performance.md](performance.md) |
| Gamepad on hardware | UNVERIFIED | Map is in `game.gd`; no pad attached |
| Audio in the browser | UNVERIFIED until a gesture inside the game view | Web audio needs a click in the game document |

Checksums of the local export (sha256):

```text
fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0  web/index.wasm
247fa3fd858d6b59daedb175493c868b7b81d1b8ebdfff8f9c8713f7349a08be  web/index.pck
33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba  web/index.js
cd76b07979073e60e80740e1e2d9fad45cd5406e9bd30bc74cc0e995ad3abada  linux/relay-breach.x86_64
```

Do not treat a green headless run as a graphical playtest.
