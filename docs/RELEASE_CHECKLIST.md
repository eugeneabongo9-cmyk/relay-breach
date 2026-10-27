# Release checklist

Status from the session that produced 0.9.0. Evidence is a command or a file, not a vibe.

| Gate | Status | Evidence |
| --- | --- | --- |
| Clean import | PASS | `godot --headless --path . --import --quit` |
| Headless tests | PASS | `tests/run_tests.gd` → `RESULT passed=364 failed=0`, also on [Actions run 40580439854](https://github.com/eugeneabongo9-cmyk/relay-breach/actions/runs/40580439854) |
| GitHub Actions | PASS | Same run: `test` and `export-web` on ubuntu-24.04, Godot 4.7.2. Runs 40578775847 and 40580197901 failed at workflow parse and never started a job. |
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
4574fc0746e2dfa0cd4501b7478e494bc6c1a8bf7d83ea55965a128ccb185d73  linux/relay-breach.x86_64
bca2c745fa7a195d8d191abc1382feb5af28de7af27883b814a1527ed0d74574  web/index.pck
fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0  web/index.wasm
33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba  web/index.js
208e20c3d72fea999bbfae441bda9faf3b4e32081e1b6eb8a1c54e8cde2716d5  web/index.html
```

Those files are attached to [v0.9.0](https://github.com/eugeneabongo9-cmyk/relay-breach/releases/tag/v0.9.0), exported from commit 9882931. wasm and js match the earlier export. The pck and the Linux binary changed after movement stepped by the tick delta.

Do not treat a green headless run as a graphical playtest.
