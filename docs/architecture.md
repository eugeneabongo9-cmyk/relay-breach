# Architecture

```text
content.json
    │
    ▼
ContentDB ──► ContentValidator (authoring, no scene)
    │
SaveService ──► SaveCodec (version, migration)
    │
Game (input, pause flag, settings, audio, QA probe)
    │
    ▼
game_root (one room at a time)
    ├── player.gd          movement, evade, shock
    ├── enemy_actor.gd     body + EnemyBrain
    ├── projectile.gd
    └── hud.gd             menus, remap, touch
```

Rules live in `scripts/rules/` as `RefCounted` types with no node tree. The room script asks them whether a link is legal, then plays the result. That split is what the headless tests actually call.

## Decisions

**One scene, rooms built in code.** Hand-authored encounters live in JSON (positions, archetypes, obstacles). Meshes are built when the room starts and freed with `remove_child` + `free` so a restart does not wait on `queue_free`. A library of `.tscn` rooms would duplicate the same boxes.

**Pause is not the tree pause.** `Game.paused` stops `_sim`. The pause UI is a normal `CanvasLayer`. Combat timers go through `CombatRules.advance`, which no-ops while paused. Camera trauma never calls that function.

**Fixed isometric basis.** `CameraBasis` caches forward and right from offset `(12, 16, 12)` once. Shake moves the camera but not those axes, so A/D cannot flip mid-rumble. A is `-right` (screen-left under this camera). The yaw probe uses `atan2(-vx, -vz)` only so a strafe test can see the facing change. The body itself does not steer like a vehicle.

**Saves at room boundaries only.** Mid-fight progress is discarded on death; retry rebuilds the saved room with the same seed and upgrades. A newer `version` is refused. A content version mismatch drops the run and keeps settings. Writes go to `user://*.json.tmp`, then replace, after copying the previous file to `.bak`.

**What we do not promise.** Seeded room order is deterministic. Physics, animation frames, and web audio clocks are not a replay format.
