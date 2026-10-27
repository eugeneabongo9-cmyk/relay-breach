# Evidence

| Claim | Where |
| --- | --- |
| One tether does three jobs | `game_root.gd` shield link, coil damage, extract charge. Tests: shield expose, door hold, finale victory. |
| Illegal links explain themselves | `TetherRules.reason_text`. Tutorial smoke expects `incompatible` on bus→dump. |
| Data, not hardcoded rooms | `data/content.json`. Validator + `invalid_room.json`. |
| Seeded order, separate cosmetic stream | `RunGenerator`. 32-seed test. |
| Saves migrate and survive a bad write | `SaveCodec`, `SaveService`, `save_v0.json`. |
| Pause does not freeze the UI or change rules via hit-stop | `Game.paused`, `CombatRules.advance`. Pause test on cooldown. |
| Enemies recover when stuck | `EnemyBrain._track_stuck`. |
| Restart does not pile nodes | smoke counts nodes across 10 shield restarts. |
| Input remap can be undone | Settings plus Shift+F10 in `game.gd`. |
| Debug tools stay out of release | F3/F4/F6/F8 check `OS.is_debug_build()`. |
| A/D match the isometric camera | `CameraBasis` plus the held-key smoke (A increases yaw, D decreases it). |
| Performance number is real and limited | `LOGIC_STRESS` line. GPU column is UNVERIFIED on purpose. |

No playtest cohort, no shipped-title history, and no fps trophy is claimed.
