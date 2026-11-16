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
  (`FindAllOf`) on a repeating timer or in a hook: 0.4.1 has no repeating scan at all (a 3 s `FindAllOf` was a visible hitch,
  user report 2026-11-16). `registry.lua`: ships (`Base_Frigate_C`) and pods (`MasterPod_C`) report themselves from
  `ReceiveBeginPlay` (and the ship's own 1 s timer event `CustomEvent_4`, the `BehSelectTimer` of `Base_Frigate`), the
  modules take a few ships per 0.5 s call, nothing runs on foot. One `FindAllOf` per class, once, when the class is first hooked.
- Everything is on by default, automatic, with its own switch in `config.lua`; a new part ships OFF until it has
  been tested in the game. All parts were tested on 2026-11-14 (section 8) and ship ON: pod catchers with the faction credit,
  enemy doctrine, ship damage, allied retreat (the shared target stays off).
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
full; an ally nearer the pod than you and within `Range` catches it. Credit goes to the player by default.

**Grace window (0.4.0, in the code, offline-tested).** Each free, started pod is tracked by full name from the first scan
that sees it (`firstSeen`); only after `GraceSeconds` (default 8: the game's own catch needs a few seconds of
approach and lock and the perk takes a pod every 10 s, so 8 s is quick but leaves the player the first go; the real wait
is 8 to 10.5 s with the 2.5 s scan) may an ally take it. Entries that are not free and started any more (caught by the
player, destroyed, tags cleared) are dropped on every scan, so a pod that comes back starts a new clock. Offline test
(mock pods and ships, 17 checks): no catch before 8 s, catch after, forgotten when caught or destroyed, slots full,
perk on, player nearer.

**Faction credit (0.4.0, the default, tested in the game 2026-11-14, see section 8).** What the data says:
- The pod's catch flow (`MasterPod` ubergraph, read in the dump) ends in `GetShip(...).Ship.AddCaptive(self.Captive, false)`:
  the player's ship, whatever actor was given to `CatchByMother`. So the game's catch cannot credit anyone else.
- A captive (`S_CaptiveData`: Name, Portre, Price, pirate flag) is only a list entry on `Q1_Master_Ship.Captives` that is sold
  at the captive market for its Price. There is no captive store for the faction or its armies (research note 2026-11-13).
- The faction does have a currency: Faction Power, `Game_Builder.FactionPower`, with the callable
  `"Add Remove Faction Power"(Amount:Int, out, out)` that the Faction Power mod already uses in the game
  (`Q1Controller.GameBuilderRef`).
So "faction" mode skips the game's catch: an ally within `FactionRange` of the pod (and nearer than the player, after the
grace window) adds `FactionPowerPerPilot` to the faction and the pod is destroyed (`K2_DestroyActor`, what the tests use
to clean up pods). Captive slots are not involved. Costs: the ally does not fly the pod in (no cable animation), the
mission objective "catch a pod" is not completed, and the amount is flat (50), not the pilot's Price: reading the
price needs the struct member name with its GUID suffix, left out. It bypasses the Faction Power mod's own budget
and diminishing returns (it calls the game directly): a pilot is small (50 against 300 to 600 for a mission).
Not verified in the game: the call from this mod, that destroying the pod is harmless for the game, that Faction Power
really rises by 50, and whether this mode feels right with allies that rarely pass within 1 km of a pod.

**Bigger Armies guard.** If Bigger Armies' `scripts\podcatch.lua` exists (0.2.0 only), it is enabled
(`mods.txt` line `BiggerArmies : 1`, or no line and an `enabled.txt`) and its `config.lua` leaves
`PodCatchers` on, this mod does nothing for pods and logs it once. A double catch could not happen anyway
(the first catch clears the `FreePod` tag), but two mods doing the same work would double-count slots. To
check in the game: which wins when `mods.txt` says `: 0` and an `enabled.txt` exists.

## 3. Smarter allied ships (in 0.2.0, on by default: retreat only, shared target off; partly tested, section 8)

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
- **In the code (`allies.lua`)**: every `Interval` s, on the ships of the registry (`registry.lua`), for each living ally (`AITypes` 1; `ShipType` 0 Frigate, 1 Fly or 12 HeavyFighter; not a creature,
  non-combat ship, character shooter or fleet `General?`):
  - **Retreat** uses `Master_Enemy.ReturnToSpawn`, the flag the game itself sets when a ship strays from its
    `SpawnRoot` (3.5 km, 5.5 km when the root is the player, 140 m for a low squad soldier; read in the
    Blueprint). While it is set the AI flies to `SpawnRoot` (the player's pawn when invalid), clears the flag within
    50 m, and moves a ship that is 4.6 km or more away onto the root. So: set the flag below `Retreat.Below`
    (health = `(CurrentArmor + CurrentShield) / (MaxArmor + MaxShield)`) when the ship is within `MaxDistance`
    (default 3 km) of its root (no teleport); set it again if the game cleared it on arrival; clear it above
    `ResumeAbove`, or after `MaxSeconds` followed by a 60 s pause. `ChangeState(3)` was not used: the state
    switch on `AIState` is native and was not readable; `ChangeState` only stores the state and starts a state timer.
  - **Shared target**: `SetOrderAttackTargetFromTacticMap(Target)` (read: sets `MainTarget`, calls `TargetIsChanged`,
    sets `MainTargetSettedBy Order`) with the player's `LockedTarget` (an enemy, `AITypes` 0), for allies with
    `HasSquad?` false, not retreating, within `ShareTarget.Range` of the player, once per new target.
  - Never: the player's ship (other class), enemies, aliens, civilians, cargo, drones, capital, command and mother
    ships.
- **Not verified in the game**: that setting `ReturnToSpawn` from Lua has the effect the Blueprint suggests; what a
  ship inside a squad does (the formation code checks the flag, the distance check is skipped for squads);
  whether `MainTargetSettedBy Order` keeps the target against retargeting; whether allies repair armor at all
  (shield recharge is certain, so the resume threshold may need `MaxSeconds`); what the player sees when an ally
  idles at its root. Ships that carry the flag when the mod stops are left as they are (the game clears it).

## 4. Enemy ships by tier (in 0.1.0, on by default; tested in the game, section 8)

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
- **In the code (`doctrine.lua`)**: every `Interval` s, from the registry (0.4.1; 0.4.0 had its own `FindAllOf("Base_Frigate_C")`); for each living enemy
  (`AITypes` 0, not a creature, non-combat ship or character shooter) of low tier (`Faction` 3 Pirates, or a military
  faction (0 Morthra, 1 Falron, 2 Xeghan) at `Enemy_Rank` <= `LowRank`; never aliens 4, none 5 or the player's own faction 6): `CloseTrueBeheviur = 0` once, and `ShipBaseTurnSpeed x SloppyTurn`, re-applied when
  the game recalculates the ship's stats and replaces our value. Military ranks above `LowRank` are untouched
  (disciplined = as the game flies them). Later: hold the band, share targets, retreat when badly damaged.
- **Not verified in the game**: whether `CloseTrueBeheviur = 0` really removes the pass (the pass is also entered
  when `CanMakeSpeedAdjustmants?` is false), whether the written values persist, and whether the close pass is
  what the player sees as a rush. The first test launch (2026-11-13) did not get past the main menu; in the 2026-11-14 tests the
  values were written and held, and in flight a pirate never started the close pass while a vanilla ally did (section 8).

## 5. Ship damage that matters (NPC hull states in 0.3.0, on by default, tested in the game; player ship researched only)

- Game model: shield, then armor, by damage type (Bullet, Laser, Missile), crit, DoT, slow, blind, all in
  `Damage_Component:Damage1`. No engine, weapon or shield part. Only capital ships have real parts: left alone.
- Plan for NPC ships: hull-state degradation by health ratio through the once-written values (engines:
  speed and turn; shields: recharge; weapons: fire rate), applied once per threshold crossing, polled on the
  timer. Not locational.
- Player ship: damage arrives in `ReceiveAnyDamage` (no hit location, only the causer). Flags exist
  (`EngineOff?`, `DisableWeapons?`, thrust and speed multipliers) but which ones `CalculateStats` recomputes is
  unchecked: no player-ship writes before that is read.
- Do not hook `Damage1` or `ReceiveAnyDamage` (they run per hit): poll on the timer instead.
- **In the code (`hull.lua`, `shipmods.lua`)**: on the ships of the registry, for living enemy and allied fighters and
  frigates (`shiputil.kind`: `ShipType` 0, 1 or 12, not aliens, creatures, non-combat, shooters, generals), health =
  `(CurrentArmor + CurrentShield) / (MaxArmor + MaxShield)` (skipped while the maxima are 0). Stages from
  `ShipDamage.Stages` (default below 66 %: speed and turn x0.85; below 50 %: and shield recharge x0.5; below 33 %: speed
  and turn x0.65), the deepest reached applies, hysteresis 5 % on the way back up. A stage is a multiplier on the
  constants `ShipBaseSpeed`, `ShipBaseTurnSpeed`, `ShieldRechargeRate`. Why these three: the game writes them in
  `CalculateStats` (`ShipBaseSpeed` and `ShipBaseTurnSpeed` from the rank table, `ShieldRechargeRate` per rank), the
  AI derives its per-cycle values from them, and `ShieldRechargeRate x 0.001` is read at each shield recharge
  step. `TurretFireRate` was left out: which direction is "worse" is unknown.
  - `shipmods.lua` is the one place that writes them: per ship the base values as the game wrote them, what we last
    wrote, and one multiplier per source (`doctrine`, `hull`). The value written is base x all multipliers; a value
    that is not what we last wrote is taken as the game's new base (the game recalculated). A ship that has had a stage
    is re-checked every scan (a few reads), a ship that never had one is never touched.
  - Verified offline only (mock objects, 35 checks): stage transitions, one write per crossing, stable over scans,
    recalculation re-applied, doctrine and hull together, repair puts the base back, capitals and aliens untouched.
- **Not verified in the game**: that a write to `ShipBaseSpeed` / `ShipBaseTurnSpeed` changes how the ship flies
  (the AI derives `MaxSpeed` and the turn speed from them each cycle: read, not seen); that a write to
  `ShieldRechargeRate` slows the recharge; whether `CalculateStats` runs again during a ship's life (the call sites
  read: ship setup, and `UpdateShipAIType`) and whether our re-apply copes; what the player notices at 15 % less speed.

## 6. Plan

- 0.1.0: pod catchers and the guard; then enemy doctrine by tier after two in-game checks (ram or strafing
  pass; do the once-written values stick).
- 0.2.0 (in, on: retreat; shared target off): allied ships. 0.3.0 (in, on): NPC hull states. 0.4.0: grace window and faction credit
  (on). Later: damage to the player's ship only after `CalculateStats` has been read. Each new part ships OFF until it has been
  tested in the game, then it is switched on by default.

## 7. Test plan (game launches only when allowed)

One launch covers 0.1.0, 0.2.0 and 0.3.0: a copy of a space save in a test slot, this mod alone plus the dev
console, every part switched on in the test copy of `config.lua` (the repo default is now all on, the shared target off). The
test kit (outside this repository) drives it with scripted ships.
1. Pods: the eight Bigger Armies cases with longer waits (grace 8 s + flight 12 s: positive cases 30 s, negative ones
   16 s so a bug would show), plus case 9 (nothing at 3 s and 6 s, the catch only after about 8 to 10.5 s), case 10 (a pod
   destroyed inside the grace window is forgotten), case 11 (`Credit = "faction"`: an ally 500 m from the pod, slots
   full, Faction Power rises by 50, pod removed, captive count unchanged) and case 12 (faction mode, ally 4 km away:
   untouched). (Run 2 runs the faction cases in a launch whose test config has `Credit = "faction"`.) The Bigger Armies guard with the real `Mods` path (a Bigger Armies 0.2.0
   snapshot sits in the test copy, off: the guard is called with `mods.txt` saying `BiggerArmies : 1`, then with its
   `PodCatchers` off; booting with it on is covered offline, 7 mock folders, and by the log line).
2. Doctrine: scripted pirate and military frigates; read the values before and after, sample the distance
   to the player every 0.5 s for 30 s, check the close pass is gone and the values persist.
3. Retreat (0.2.0): a scripted allied frigate with 15 % health: the flag is set, its distance to the root falls, no
   despawn, it rejoins after repair; a healthy ally is left alone; one too far from its root is left alone; the
   player's locked target reaches a healthy ally's `MainTarget` once; a ship inside a squad (an allied one if the
   save has any, otherwise an enemy squad member with the flag set by hand) is watched to see whether it follows.
4. Hull states (0.3.0): scripted frigates set to 60, 45, 20 % health: each stage writes once (speed x0.85, then shield
   x0.5, then speed x0.65), nothing changes over the next 20 s, a `CalculateStats` call is answered by one re-apply,
   repair puts the base back; with the doctrine on the pirate's turn is base x0.85 x stage; capital and player untouched.
5. Cost: 30 s with six enemy and four allied frigates and everything on, log size, private bytes every 30 s, the longest
   gap between timer ticks, no crash.

## 8. In-game test results (2026-11-14, three launches of the 0.4.0 build)

Own test slot (a copy of "Entered New System"), HSR alone plus Bigger Armies 0.2.1 (no `podcatch.lua`) switched on, dev console,
scripted ships. Launch 1 ran the 0.1 to 0.4 list, launches 2 and 3 repeated what had not been checked. Memory stayed flat
(about 10.1 GB private), no crash, no hang. Test kit and logs are outside this repository.

| Part | Result |
|---|---|
| Pod catch, player credit (8 cases) | PASS: caught after the grace window (about 11 s after the pod appeared), left alone when you are nearer, out of range, slots full, perk on, not an ally, idle |
| Grace window | PASS: nothing at 3 s and 6 s, the catch 8 to 11 s after the pod appeared; a pod destroyed inside the window is forgotten without error |
| Bigger Armies 0.2.1 beside HSR | PASS: BA logs "+10 general slots (up to 22)", HSR catches the pods |
| Guard, real source of `main.lua` run in the game with the real Mods path | PASS, 7 of 7: 0.2.1 on (no `podcatch.lua`) = HSR catches; a stub `podcatch.lua` standing in for 0.2.0 on = HSR leaves it; its PodCatchers off, BA off in its config, `mods.txt` says 0 = HSR catches |
| Faction credit | PASS: +50 Faction Power per pod (28843 to 28893 to 28943), pod removed, captive slots untouched (also with 0 of 0 slots), grace window held, out of range and player-nearer and perk-on left alone. With a 1 km range nothing was picked up (launch 2): the ally flew 1.2 to 1.4 km in 20 s, so the default is now 3 km. The "waits" debug note in the log shows why a pod is still waiting |
| Hull states | PASS: stages 1, 2, 3 gave the expected speed, turn and shield recharge, one write per crossing, unchanged over 22 s, `CalculateStats` re-applied within one scan, repair put the base back, doctrine and hull combine |
| Doctrine, values | PASS: `CloseTrueBeheviur` 9099 to 0 and turn 60 to 51 on low-tier enemies, held, allies untouched |
| Doctrine, in flight | PASS (one pirate, one vanilla ally as control, same fight): the ally went `Close?` = true with `SpeedMultipler` 2.0 at about 265 m and closed to under 100 m; the pirate, inside 98 to 265 m of its target many times, never had `Close?` and kept 1.2 |
| Doctrine scope | enemies only (`AITypes` 0). Factions seen: 3 Pirates, and 0 Morthra and 1 Falron frigates at rank 1 (every scripted M_Frigate comes out at rank 1, so a military ship counted as low tier by rank, as designed). Aliens (4), none (5) and the player's faction (6) are now excluded in code. A rank 4 control could be set after the spawn (the game resets rank during the first seconds) but the ordered ships never closed on you, so the rank-4 flight comparison was not made |
| Retreat flag | PARTLY: the flag is accepted and the hurt ally (15 %) flew back toward its root (1.0 km to 0.2 km in 40 s) and its distance to the enemy grew from 160 to about 490 m; the game clears the flag again within about 2 s while the ship is engaged, so the mod sets it again on each scan (seen as short flickers). After repair it set the base values back and the distance to the enemy fell again. The timeout path (120 s) worked. Not shown: a clean, decisive withdrawal |
| Shared target | NOT RECOMMENDED: an order from the mod or by hand sets `MainTarget` and `MainTargetSettedBy Order`; it stuck for at least 30 s while the target was near and fought, and was cleared by the AI about 12 s after the target was far (launch 2). The ally then stayed without a target for 70 s with an enemy 500 m away shooting at it: the "ordered" flag seems to keep the AI from choosing a target. In launch 3 the ordered far target was not cleared in 100 s and clearing the flag by hand changed nothing, but the world was nearly standing still then. So it ships OFF |
| `TryToGetBack?` on a healthy ally, ally inside a squad | INCONCLUSIVE: the world was nearly standing still during the launch 3 fight phase (ships moved metres in 2 minutes) and the save has no squad ship |
| Cost | the HSR log grew about 1.2 to 1.4 KB in 35 s with ten frigates and every part on; no tick gap over 2 s; the fleet fight itself did not engage (the world stood still), so a real fleet fight is still not measured |

What stays open: a decisive retreat (maybe `TryToGetBack?`, which the AI uses itself after five chase passes), a squad ally, the
rank 4 flight control, a real fleet fight, and whether the near-standstill of far ships is the game's own optimization layers
(`OpLayerIndex`, `CheapModeON?`, read in the Blueprint) or the window losing focus.
