# Rules

Numbers below are the defaults in `data/content.json`. Arc Lens adds 4 m to tether range. Capacitor Well adds 40 max energy. Phase Step subtracts 0.28 s from evade cooldown (floor 0.2 s).

## Tether

One link. Cost 18 energy up front, then 7 per second, for at most 6 seconds. Cooldown 1.15 s after it ends. Line of sight is against room obstacles only, not actors. If either endpoint is removed, the link ends as `missing`.

| Pair | While the link is held |
| --- | --- |
| shield_gen + dump | Shielded enemies can be damaged |
| bus + coil | Coil deals 26 damage/s within 3.4 m |
| bus + door | Door opens after 0.55 s (tutorial exit) |
| bus + jammer | Support units cannot heal |
| reactor + extract | Extract charges. 4 s wins. Charge decays at 0.45/s while unlinked |

A rejected preview says why: same, incompatible, range, los, energy, cooldown, busy, missing, disabled.

Player shock is 13 damage at 2.6 m, 0.4 s cooldown. It does not pierce a shield. Evade is 0.2 s of movement at 16 m/s with 0.18 s of invulnerability, then 0.9 s cooldown.

## Enemies

| Archetype | Behavior |
| --- | --- |
| Pursuer | Chase. Inside 2.15 m: telegraph 0.5 s, lunge 0.28 s, recover 0.48 s. 18 damage once per lunge if still in range. |
| Sentinel | Stands still. Inside 13.5 m: telegraph 0.64 s, fires one bolt, recover 0.7 s. Often starts shielded. |
| Support | Closes to about 5.5 m. Telegraph then heals allies for 16. Suppressed while a jammer link is up. |

Perception is a radius (18 / 15 / 16). Pursuers and supports that fail to move for 1.35 s (1.5 s for support) sidestep for 0.45 s, then chase again. They do not pathfind around arbitrary geometry; the sidestep is the recovery.

## Run

Order is tutorial, a shuffle of shield / coil / support / mixed, then the finale. The shuffle uses only the run seed. After a clear room, pick one remaining upgrade (three total, no repeats). The finale is won by the extract, not by killing everyone. Death retries the current room from the boundary save.
