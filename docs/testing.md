# Testing

```bash
godot --headless --path . --import --quit
godot --headless --path . -s res://tests/run_tests.gd
```

`tests/run_tests.gd` exits 1 on failure. Godot sometimes still returns 0 when a script fails to parse, so CI also requires the line `RESULT passed=… failed=0`.

Covered:

- Tether pairs, range, exact energy cost, cooldown, busy, missing, disabled, blocked sight.
- Damage vs iframe, and timers that do not move while paused.
- Pursuer telegraph → attack → recover, sentinel windup, suppressed support, stuck sidestep.
- 32 seeds: tutorial, four unique encounters, finale. Cosmetic RNG does not change the order stream.
- Save v0 migration, newer-version refusal, malformed JSON, atomic replace with `.bak`, settings defaults.
- Scripted tutorial: move, bolt, rejected dump, door link, exit. Not a debug win button.
- Shield link exposes the sentinel and dropping it restores immunity. Removing an endpoint cancels the link.
- Finale reactor–extract hold reaches victory (enemies cleared first so the assertion is about the link, not survival).
- Ten restarts of the same room keep the node count within 8.
- Stress yard: 24 pursuers, 120 logic ticks. Printed as `LOGIC_STRESS`.

Headless success does not prove the camera read, web audio, or a gamepad. Browser checks are separate and listed in the release checklist.
