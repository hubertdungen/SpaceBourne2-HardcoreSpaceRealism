# Hardcore Space Realism for SpaceBourne 2

![Hardcore Space Realism](docs/banner.png)

A [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod: the space counterpart of
[Hardcore Tactical Realism](https://github.com/hubertdungen/SpaceBourne2-HardcoreTacticalRealism).
Everything is on by default, automatic, with no keys and no menus. Part of the SpaceBourne 2 realism set.

<!-- nexus:skip -->
> **Status: 0.4.0.** Everything is **on by default**: the ally pod catchers (with a grace window, the pilot credited to your
> faction), the enemy doctrine, the allied retreat and the ship damage. Each has its own switch in `config.lua`. All of it was
> checked in the game on 2026-11-14 with scripted ships. **Not tested:** an allied ship inside a squad and a full fleet fight.
> The allied retreat is not a clean withdrawal (see below). The shared target is off. [DESIGN.md](DESIGN.md) has the research
> and the test results.
<!-- /nexus:skip -->

## What it does

**Ally pod catchers (0.1.0).** When a ship dies its pilot ejects in a rescue pod. The game lets only
you catch it: with your mothership's pod catcher perk or the pod catcher item. With this mod an
allied ship that is closer to a free pod than you are, and within range, catches it. The pilot goes
to **your** captives, exactly as if you had caught it. Nothing is caught when your captive slots are
full or when your own mothership perk is on (it already takes every free pod).

You get the first chance: a pod must have been free for `GraceSeconds` (8 by default, so 8 to 10.5 s with the
scan interval) before an ally takes it. That is quick, the pod is not lost, but it is not instant. A pod you
catch (or that is destroyed) in that time is simply forgotten.

**Faction credit (0.4.0, on by default).** With `PodCatchers.Credit = "faction"` (the default) the pilot goes to
your faction instead of your captive slots: an ally within `FactionRange` (3 km) of the pod picks it up, your
faction gets `FactionPowerPerPilot` (50) Faction Power (the same game call the Faction Power mod uses) and the pod
is removed. No slot is used. The game's own catch always ends in your captive list, so this mode skips it: the ally
must already be near the pod (it does not fly it in) and the mission objective "catch a pod" does not complete.
<!-- nexus:skip -->Tested in the game (2026-11-14): the Faction Power rose by 50 per pod, the pod was removed, nothing was used from the
captive slots (even with them full) and the grace window held. Allies move about 60 m/s, which is why the range is 3 km.<!-- /nexus:skip -->
An ally within 3 km of the pod is enough, because allies keep moving.
Set `PodCatchers.Credit = "player"` to get the pilots in your own captive slots instead (the game's own catch, also tested).
`"player"` stays the default until it is decided which credit the set wants.

**Enemy doctrine by tier (0.1.0, on by default).** In the game every enemy fighter and frigate ends its
run with a "close pass": it doubles its speed and dives at you. With this on, the low tiers (pirates, and
ranks up to `LowRank`) never do that, so they keep shooting from their normal attack distance, and they
turn a little slower (sloppy). Higher ranks of the military factions fly as the game has them. Never touched: allied
ships, aliens, ships with no faction and the player's own faction. <!-- nexus:skip -->Tested in the game: a pirate inside 100 to 265 m of
its target never started the close pass while a vanilla allied ship did.<!-- /nexus:skip --> Switch it off with `EnemyDoctrine.Enabled = false`.

**Smarter allied ships (0.2.0, on by default: retreat only).** In the game an allied fighter or frigate fights until it
dies. With this on, an ally whose armor and shield are below 25 % pulls back with the game's own "return to
spawn" flag (it flies to where it came from, or to your ship, and the game stops it there). It rejoins when
it is above 60 % again (shields recharge by themselves) or after two minutes, whichever comes first. Allies
that are not in a squad can also be sent after the target you have locked (`ShareTarget.Enabled`, **off**: in the game an
ordered ally keeps that one target and can go passive when it is lost). Never touched: your
ship, enemies, aliens, civilians, cargo, drones, capital ships, command and mother ships. **Honest limits:** in the game the
hurt ally flew back toward where it came from and rejoined after repair, but the game clears the flag again within about
2 s while the ship is engaged (the mod sets it again every few seconds), so it is not a clean withdrawal; an ally inside a
squad was not tested. Switch it off with `AlliedShips.Enabled = false`.

**Ship damage that matters (0.3.0, on by default).** The game has one damage model: shield, then armor, with no
engine or weapon parts. So a ship's state comes from its health (armor + shield against their maximum). Below
66 % its engines and turning drop by 15 %; below 50 % its shield also recharges at half speed; below 33 % engines and
turning are at 65 %. Each stage is written once when the ship crosses it, to constants the game computes once per
ship (and re-applied if the game computes them again). Enemy and allied fighters and frigates. **Your own ship is
not touched**, nor are aliens, civilians, cargo, drones or capital ships. <!-- nexus:skip -->Tested in the game: each stage written once,
re-applied after the game recalculated the ship, restored on repair.<!-- /nexus:skip --> Switch it off with `ShipDamage.Enabled = false`.

*Planned, not yet in:*
- **Damage to your own ship** (engines off, weapons down): only after the game's stat recalculation for the player's
  ship has been read, so a write is not undone.

## Settings

Edit `HardcoreSpaceRealism/scripts/config.lua`, save, restart the game.

| Setting | Default | |
|---|---|---|
| `Enabled` | `true` | Master switch. |
| `PodCatchers.Enabled` | `true` | Allied ships catch free pods. |
| `PodCatchers.Range` | `5000` | Metres. An ally this close to a pod, and nearer than you, catches it. |
| `PodCatchers.Interval` | `2.5` | Seconds between checks. |
| `PodCatchers.GraceSeconds` | `8` | A pod must have been free this long before an ally takes it: you get the first chance. |
| `PodCatchers.Credit` | `"faction"` | `"faction"`: Faction Power for your faction, no slot used. `"player"`: the pilot goes to your captive slots. Both tested in the game. |
| `PodCatchers.FactionRange` | `3000` | Metres. `"faction"` mode: an ally this close to the pod picks it up. |
| `PodCatchers.FactionPowerPerPilot` | `50` | `"faction"` mode: Faction Power per pilot (the Faction Power mod pays 300 to 600 for a mission or dungeon). |
| `EnemyDoctrine.Enabled` | `true` | Low-tier enemies skip the close pass and turn slower. |
| `EnemyDoctrine.LowRank` | `1` | Enemy rank up to this is low tier (pirates always are). |
| `EnemyDoctrine.SloppyTurn` | `0.85` | Low-tier turn speed multiplier (1 = unchanged). |
| `EnemyDoctrine.Interval` | `3.0` | Seconds between scans. |
| `AlliedShips.Enabled` | `true` | Allies retreat when badly damaged (and, if switched on, attack your locked target). |
| `AlliedShips.Retreat.Enabled` | `true` | Retreat part of the above. |
| `AlliedShips.Retreat.Below` | `0.25` | Health ratio (armor + shield) under which an ally pulls back. |
| `AlliedShips.Retreat.ResumeAbove` | `0.6` | It rejoins the fight above this. |
| `AlliedShips.Retreat.MaxSeconds` | `120` | It rejoins after this long whatever its health (then waits 60 s). |
| `AlliedShips.Retreat.MaxDistance` | `3000` | Metres from its root. Farther away it stays in the fight. |
| `AlliedShips.ShareTarget.Enabled` | `false` | Allies outside a squad are sent after your locked target (off: see above). |
| `AlliedShips.ShareTarget.Range` | `20000` | Metres from you: only allies this close are told. |
| `AlliedShips.Interval` | `3.0` | Seconds between scans. |
| `ShipDamage.Enabled` | `true` | NPC ships fly, turn and recharge shields worse as they lose hull. |
| `ShipDamage.Enemies` / `Allies` | `true` | Which ships it applies to. |
| `ShipDamage.Stages` | 66 / 50 / 33 % | `Below` (health ratio) with `Speed`, `Turn` and `Shield` multipliers; the deepest stage reached applies. |
| `ShipDamage.Interval` | `3.0` | Seconds between scans. |
| `Debug` | `false` | Writes what the mod does to `hardcorespacerealism.log`. |

## Works with Bigger Armies

Bigger Armies 0.2.0 had the same pod catchers. If it is installed and on with its `PodCatchers`
setting on, this mod leaves the pods to it and says so once in its log. Bigger Armies 0.2.1 and
later no longer has them: update it and this mod takes over.

## Install

**A. SpaceBourne 2 Realism installer (recommended)**
The [installer](https://github.com/hubertdungen/SpaceBourne2-Realism) installs UE4SS if you don't have
it, switches the mods you tick on and keeps them updated.

**B. By hand**
1. Install UE4SS 3.0.1 for SpaceBourne 2: put `dwmapi.dll`, `UE4SS.dll` and `UE4SS-settings.ini` in
   `SB2\Binaries\Win64`.
2. Copy the `HardcoreSpaceRealism` folder to `SB2\Binaries\Win64\Mods`.
3. Add the line `HardcoreSpaceRealism : 1` to `Mods\mods.txt` (or keep the empty `enabled.txt` in
   the mod folder).

## Limits

- With the default faction credit the ally does not fly the pod in: it picks it up when it is within 3 km, the pod just
  disappears (no catcher drone) and the mission objective "catch a pod" does not complete. Set `PodCatchers.Credit = "player"` for the
  game's own catch.
- Retreat pulls a badly hurt ally back toward where it came from, but it is not a clean withdrawal: the game keeps
  switching its own flag off while the ship is engaged. An ally inside a squad may behave differently.
- The shared target (allies attack the target you have locked) is in the config but off: an ordered ally can end up with no target.
<!-- nexus:skip -->
- Tested in the game with scripted ships and pods (2026-11-14). Not tested: an allied ship inside a squad and a full fleet fight.
<!-- /nexus:skip -->

## Compatibility

Pure Lua, no game files replaced. Timed work uses `gametick.lua` (no `LoopAsync`), the same
timer every mod of the set shares, so the mods do not step on each other.

## How it works

The mod looks for free pods (the game tags them `FreePod`) every few seconds on the game thread. When
an ally ship is nearest, it calls the pod's own `CatchByMother` with that ship, the same call the
mothership perk makes. Details: [DESIGN.md](DESIGN.md). Version history: [CHANGELOG.md](CHANGELOG.md).

## The SpaceBourne 2 realism set

Separate mods that work alone or in any combination. The
[SpaceBourne 2 Realism installer](https://github.com/hubertdungen/SpaceBourne2-Realism)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/11)) installs the ones you tick and keeps them updated.

- **[Hardcore Tactical Realism](https://github.com/hubertdungen/SpaceBourne2-HardcoreTacticalRealism)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/4)): realistic ballistics, wounds and tactical AI. The core of the set.
- **Hardcore Space Realism** (this mod): realism for ships and space combat.
- **[Silent Ops](https://github.com/hubertdungen/SpaceBourne2-SilentOps)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/6)): stealth, silent takedowns and suppressors.
- **[Ammo Discipline](https://github.com/hubertdungen/SpaceBourne2-AmmoDiscipline)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/12)): carried ammo limits and scavenging, so every magazine counts.
- **[Gear Without Levels](https://github.com/hubertdungen/SpaceBourne2-GearWithoutLevels)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/7)): use gear above your level, with small handling penalties.
- **[Tactical First Person](https://github.com/hubertdungen/SpaceBourne2-TacticalFirstPerson)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/15)): first person on foot, weapons held up, aiming down the sights.
- **[Tactical Engineering](https://github.com/hubertdungen/SpaceBourne2-TacticalEngineering)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/10)): realistic deployable turrets.
- **[Get Out of the Way](https://github.com/hubertdungen/SpaceBourne2-GetOutOfTheWay)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/14)): NPCs step aside naturally when you walk through them.
- **[Ground Waypoints](https://github.com/hubertdungen/SpaceBourne2-GroundWaypoints)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/13)): planet waypoints on foot and on the hoverbike.
- **[Faction Power](https://github.com/hubertdungen/SpaceBourne2-FactionPower)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/9)): dungeons, strategic sales and missions earn your faction power.
- **[Bigger Armies](https://github.com/hubertdungen/SpaceBourne2-BiggerArmies)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/17)): twice the general slots for your faction's ground and space forces.
- **[Clear HUD](https://github.com/hubertdungen/SpaceBourne2-ClearHUD)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/16)): a reticle you can see and HUD colours of your choice.
- **[Split Controls](https://github.com/hubertdungen/SpaceBourne2-SplitControls)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/5)): separate vertical invert for ship and on foot, per device.
- **[SB2 HOTAS](https://github.com/hubertdungen/SpaceBourne2-HOTAS)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/8)): HOTAS, rudder pedals, triple screens and head tracking.
- **[Squad Tactics](https://github.com/hubertdungen/SpaceBourne2-SquadTactics)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/18)): squad orders on foot: teams, point at a spot and give orders, rescue me.
- **[Unofficial Patch](https://github.com/hubertdungen/SpaceBourne2-UnofficialPatch)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/19)): fixes for game bugs, such as squad mates stuck or misplaced in lifts.

## License

MIT. See [LICENSE](LICENSE).
