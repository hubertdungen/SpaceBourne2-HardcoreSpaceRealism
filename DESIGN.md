# Design notes: Hardcore Space Realism

Maintainer notes. What the mod does, the game facts it relies on, what was researched for the next parts
and what is not verified. Game names (classes, properties) are the only things that break after a game
patch; they are listed so they can be re-checked. Decompiled game data is not part of this repository.

Status legend: **done** (in the code and tested), **researched** (read in the game's Blueprints, not yet
tried in the game), **unknown**.

## 1. Rules every part follows

- UE4SS 3.0.1: no `LoopAsync`, `ExecuteWithDelay` or `ExecuteAsync` (they race and crash the game).
  Timed work runs on the shared `gametick.lua` 1.1, pumped from the player's HUD draw. Copy it unchanged.
- No per-frame calls to functions with out-parameters (they leak in the UE4SS registry). Scans
  (`FindAllOf`) only on the timer, never in a hook.
- Everything is on by default, automatic, with its own switch in `config.lua`.
- Never write a game value the game rewrites every cycle; write once the values it computes once.

## 2. Ally pod catchers (done)

Moved from Bigger Armies 0.2.0 (`podcatch.lua`, unchanged). Game facts:
- Free rescue pods are `MasterPod_C` with the tag `FreePod`. Calling `MasterPod:CatchByMother(Actor)` clears
  the tags, flies the pod to that actor and ends with `AddCaptive` on the player's ship. The mothership perk
  (`Q1_Master_Ship:MotherPodCatcher`, flag `MoahterPodCathcerActive`) calls the same function every 10 s.
- Allied ships are `Master_Enemy_C` with `AITypes == 1`. The player's ship is the controller's pawn
  (`FindFirstOf("Q1_Master_Ship_C")` can return another object of the class with no captive list).
- Destroyed actors stay valid for `IsValid()` until garbage collection and report the origin: filter with
  `IsActorBeingDestroyed` and an origin check, and remember pods already caught.
- Captive slots: `Captives` array length against `Max Captive`; catches in flight (12 s) count as used.

Mod behaviour: every `Interval` seconds find free, started pods; skip all if your perk is on or slots are
full; an ally nearer the pod than you and within `Range` catches it. Credit goes to the player; a separate
faction account would need a new stat and is not done.

**Bigger Armies guard.** If Bigger Armies' `scripts\podcatch.lua` exists (0.2.0 only), it is enabled
(`mods.txt` line `BiggerArmies : 1`, or no line and an `enabled.txt`) and its `config.lua` leaves
`PodCatchers` on, this mod does nothing for pods and logs it once. A double catch could not happen anyway
(the first catch clears the `FreePod` tag), but two mods doing the same work would double-count slots. To
check in the game: which wins when `mods.txt` says `: 0` and an `enabled.txt` exists.

## 3. Smarter allied ships (researched)

- All NPC ships are `Master_Enemy_C : Pawn`; the flight AI is Blueprint in `Base_Frigate_C` (fighters and
  frigates), so it can be read and steered from Lua.
- Already in the game: squads (`S_Squad`), orders `Squad_Orders` (Free, Formation, Break, AttackToMyTarget,
  CoverMe, BreakToSuddenAttack, Kapan), formation slots, a member copying its leader's `MainTarget`.
- **Missing: retreat when damaged.** `Base_Frigate` never reads armor or shield. Plan: per ally, health ratio
  `(CurrentArmor + CurrentShield) / (MaxArmor + MaxShield)`; below a threshold call `ChangeState(ReturnToSpawn)`
  or `Order(TryToGetBack)` and release it once repaired. Open: ships without `SpawnRoot`; what `ReturnToSpawn`
  does to player-faction ships; do not use `Warp Away` (it may despawn).
- Shared target for allies outside a squad: `Master_Enemy:SetOrderAttackTargetFromTacticMap(Target)` sets
  `MainTarget` and `MainTargetSettedBy Order`.
- Not read: `Tacticle_Spawn_System`, the faction fleet-battle manager that owns "general" ships.

## 4. Enemy ships by tier (in 0.1.0, off by default, not tested in the game)

- Tier data on each ship: `AITypes`, `Faction` (Morthra, Falron, Xeghan, Pirates, Aliens, None, Earthling),
  `Level`, `Enemy_Rank`, `ShipType`, `ShipSize`.
- Written once by the game (write after it, once): `ShipBaseSpeed`, `ShipBaseTurnSpeed`, `TurretFireRate`,
  `BaseTurretDamage`, `ShieldRechargeRate`. Never written by the game (instance defaults): `AttackDistMax`,
  `CloseTrueBeheviur`, `CloseBoolDistance`, `AvoidTurnSpeed`, `DefaultTurnSpeed`. Rewritten every cycle, do not
  touch: `SpeedMultipler`, `TurnSpeedMultipler`, `RangeMultipler`, `AttackDistMin`, `MaxSpeed`, `Turn speed`.
- The rush is the **close pass**: inside `CloseTrueBeheviur x RangeMultipler` the ship sets `Close?`,
  doubles speed, halves turning and aims at a random point 400 m from the target, leaving at
  `CloseBoolDistance`. No deliberate ram was found; the game's "Kamikaze" is the player's drone mechanic.
  Ship-to-ship collision damage is unverified.
- Defaults of `Base_Frigate_C`: `AttackDistMin` 160 m, `AttackDistMax` 840 m, `CloseTrueBeheviur` 91 m (x `RangeMultipler`,
  2 against the player's ship), `CloseBoolDistance` 300 m. The pass is only entered below the attack band.
- **In the code (`doctrine.lua`)**: every `Interval` s, `FindAllOf("Base_Frigate_C")`; for each living enemy
  (`AITypes` 0, not a creature, non-combat ship or character shooter) of low tier (`Faction` 3 Pirates, or
  `Enemy_Rank` <= `LowRank`): `CloseTrueBeheviur = 0` once, and `ShipBaseTurnSpeed x SloppyTurn`, re-applied when
  the game recalculates the ship's stats and replaces our value. Military ranks above `LowRank` are untouched
  (disciplined = as the game flies them). Later: hold the band, share targets, retreat when badly damaged.
- **Not verified in the game**: whether `CloseTrueBeheviur = 0` really removes the pass (the pass is also entered
  when `CanMakeSpeedAdjustmants?` is false), whether the written values persist, and whether the close pass is
  what the player sees as a rush. The first test launch (2026-11-13) did not get past the main menu, so the
  doctrine ships OFF until the checks in section 7 pass.

## 5. Ship damage that matters (researched)

- Game model: shield, then armor, by damage type (Bullet, Laser, Missile), crit, DoT, slow, blind, all in
  `Damage_Component:Damage1`. No engine, weapon or shield part. Only capital ships have real parts: left alone.
- Plan for NPC ships: hull-state degradation by health ratio through the once-written values (engines:
  speed and turn; shields: recharge; weapons: fire rate), applied once per threshold crossing, polled on the
  timer. Not locational.
- Player ship: damage arrives in `ReceiveAnyDamage` (no hit location, only the causer). Flags exist
  (`EngineOff?`, `DisableWeapons?`, thrust and speed multipliers) but which ones `CalculateStats` recomputes is
  unchecked: no player-ship writes before that is read.
- Do not hook `Damage1` or `ReceiveAnyDamage` (they run per hit).

## 6. Plan

- 0.1.0: pod catchers and the guard; then enemy doctrine by tier after two in-game checks (ram or strafing
  pass; do the once-written values stick).
- 0.2.0: ally retreat and shared target. 0.3.0: NPC hull states; player damage only after `CalculateStats`.

## 7. Test plan (game launches only when allowed)

One launch, a copy of a space save in a test slot, this mod alone plus the dev console:
1. Pods: the eight Bigger Armies cases; Bigger Armies 0.2.0 on (this mod stays out, logs once), its
   `PodCatchers` off (this mod catches).
2. Doctrine: scripted pirate and military frigates; read the values before and after, sample the distance
   to the player every 0.5 s for 30 s, check the close pass is gone and the values persist.
3. Retreat: an ally with low armor, in and outside a squad; no despawn; returns after repair.
4. Hull states: damage an enemy by script; each threshold writes once and nothing resets it.
5. Cost: 30 s of a fleet fight, log size, no crash.
