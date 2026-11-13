# Changelog

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
