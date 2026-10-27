# Content

Edit `data/content.json`. Do not retune combat in the scripts unless the rule itself changes.

- `tether` — range, cost, sustain, duration, cooldown, pairs.
- `player` — hull, energy, move, evade, shock.
- `enemies.<archetype>` — health, timings, damage. Unknown archetype names fail the validator.
- `upgrades` — id, name, desc, and one of `max_energy`, `range`, `evade_cd`.
- `encounter_pool` — room ids shuffled between tutorial and finale. Every id must exist.
- `rooms.<id>` — `player`, `exit`, `endpoints`, `enemies`, `obstacles`. Positions are `[x, z]` meters. Obstacle `size` is full width and depth. The rectangle blocks line of sight if a required segment hits it, inflated by 0.35 m.

`tools` are not required. From a debug build, F6 loads the `stress` room (24 pursuers). F8 copies a bug report: version, seed, room, upgrades, content version.

The validator (`ContentValidator`) fails duplicate upgrade ids, duplicate endpoint ids, unknown archetypes, a pool entry with no room, non-positive tether range, and any allowed pair that is present in a room but out of range or blocked. `data/fixtures/invalid_room.json` is the intentional failure. `data/fixtures/save_v0.json` is the migration fixture (`version` omitted, seed 42).

Room ids `tutorial`, `shield`, `coil`, `support`, `mixed`, `finale`, and `stress` are the slice. Adding a pool room means giving it endpoints whose pair is solvable at the base 13 m range.
