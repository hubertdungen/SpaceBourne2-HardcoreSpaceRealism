# Changelog

## 0.2.0 (not released yet)

Smarter allied ships, **off by default** until tested in the game (`AlliedShips.Enabled = true` to try them).

- Retreat when badly damaged: an allied fighter or frigate below 25 % health (armor + shield) sets the game's own
  "return to spawn" flag and flies back to its root (your ship when it has none). It rejoins above 60 %, or after
  `MaxSeconds`, then waits 60 s before it may retreat again. Ships more than `MaxDistance` from their root stay in the
  fight (the game moves a returning ship beyond 4.6 km onto its root).
- Shared target: allies outside a squad attack your locked target (the game's own
  `SetOrderAttackTargetFromTacticMap`), once per new target.
- Never touches your ship, enemies, aliens, civilians, cargo, drones, capital, command and mother ships.
- New files `allies.lua` and `shiputil.lua` (shared read-only helpers and one ship scan per second).
- Settings in `config.lua`: `AlliedShips.*`.

## 0.1.0 (not released yet)

First version.

- Ally pod catchers, moved here from Bigger Armies 0.2.0 (same code, tested there): an allied ship nearer a free
  rescue pod than you, and within range, catches it with the game's own call; the pilot goes to your captives.
  Skipped when your captive slots are full or your mothership's pod catcher perk is on.
- If Bigger Armies 0.2.0 is on with its pod catchers, this mod leaves the pods to it (logged once).
- Enemy doctrine by tier (`doctrine.lua`), **off by default** until tested in the game: low-tier enemy fighters and
  frigates (pirates, ranks up to `LowRank`) never start the game's "close pass" (double speed, dive at you) and
  turn a little slower. Only constants are written, once per ship (re-applied if the game recalculates the ship).
- Settings in `config.lua`: `PodCatchers.*`, `EnemyDoctrine.*`, `Debug`.
- Timed work uses the shared `gametick.lua` 1.1 (no `LoopAsync`).
