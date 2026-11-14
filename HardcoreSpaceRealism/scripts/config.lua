-- Hardcore Space Realism: settings. Edit, save, restart the game.
-- Everything is ON by default and automatic: no keys, no menus.

return {
    -- Master switch for the whole mod.
    Enabled = true,

    -- Allied ships catch the rescue pods (free pods) near them, for YOUR captives.
    -- Skipped when your captive slots are full or your mothership's own pod catcher perk is on.
    -- If Bigger Armies 0.2.0 is also installed and its pod catchers are on, this mod leaves the pods to it
    -- (Bigger Armies 0.2.1 and later no longer has pod catchers).
    PodCatchers = {
        Enabled = true,
        Range = 5000,    -- metres: an ally this close to a free pod, and nearer to it than you, catches it
        Interval = 2.5,  -- seconds between checks
        -- A pod must have been free this long before an ally may take it, so YOU get the first chance: the game's own
        -- catch needs a few seconds of approach and lock, and the mothership perk takes a pod every 10 s. 8 s is
        -- quick (the pod is not lost) but not instant. Checks run every Interval, so the real wait is 8 to 10.5 s.
        GraceSeconds = 8,
        -- Where the pilot goes:
        --   "player"  (tested) the game's own catch: the pod flies to the ally and the pilot lands in YOUR captive
        --             slots, as if you had caught it. Nothing is caught when your slots are full.
        --   "faction" (DEFAULT, tested in the game 2026-11-14) no captive: an ally within FactionRange of the pod
        --             picks it up, your faction gets FactionPowerPerPilot Faction Power (the Faction Power currency,
        --             the same game call the Faction Power mod uses) and the pod is removed. Your slots are not used.
        --             The game's own catch always ends in YOUR captive list, so this skips it: the ally must be close
        --             (it does not fly the pod in) and the mission objective "catch a pod" is not completed.
        Credit = "faction",
        FactionRange = 3000,        -- metres: "faction" mode, an ally this close to the pod picks it up (allies move about 60 m/s, so 1 km is too tight)
        FactionPowerPerPilot = 50,  -- "faction" mode (the Faction Power mod pays 300-600 for a mission or a dungeon)
    },

    -- Enemy fighters and frigates by tier. In the game every enemy ends a run with a "close pass": it doubles its
    -- speed and dives at you. Here the low tiers (pirates, and ranks up to LowRank) never do that, so they keep
    -- shooting from their normal attack distance, and they turn a little slower (sloppy). Higher ranks of the
    -- military factions are left as the game has them.
    -- ON by default. Tested in the game (2026-11-14): the close pass is gone for low-tier pirates while a vanilla ship still does it.
    EnemyDoctrine = {
        Enabled = true,
        LowRank = 1,        -- enemy rank (0 = weakest); pirates count as low tier whatever their rank
        SloppyTurn = 0.85,  -- low-tier turn speed x this (1 = unchanged)
        Interval = 3.0,     -- seconds between scans
    },

    -- Allied fighters and frigates (not the capital, cargo or command ships): retreat when badly damaged, and
    -- (optionally) fight the target you have locked. The game has no retreat: a ship fights until it dies. Retreat uses the
    -- game's own "return to spawn" flag, so the ship flies back to where it came from (your ship when it has no
    -- root) and the game stops it there. Health = armor + shield against their maximum.
    -- ON by default, retreat only. Tested in the game (2026-11-14): the flag is accepted, the hurt ship flies back toward its root
    -- and rejoins after repair, but the game clears the flag again within about 2 s while the ship is engaged (the mod sets it again
    -- each scan), so it is not a clean withdrawal. Not tested: an ally inside a squad, a full fleet fight.
    AlliedShips = {
        Enabled = true,
        Interval = 3.0,        -- seconds between scans
        Retreat = {
            Enabled = true,
            Below = 0.25,        -- health ratio under which an ally pulls back
            ResumeAbove = 0.6,   -- it rejoins the fight above this (shields recharge by themselves)
            MaxSeconds = 120,    -- it rejoins after this long whatever its health, then waits 60 s before it may retreat again
            MaxDistance = 3000,  -- metres from its root; farther than that it stays in the fight (the game moves a returning ship beyond 4.6 km onto its root)
        },
        ShareTarget = {
            Enabled = false,     -- OFF: allies outside a squad attack the target you have locked (once per new target). The order marks the ally "ordered" and the AI then keeps (or loses) that one target; see DESIGN.md
            Range = 20000,       -- metres: only allies this close to you are told
        },
    },

    -- Ship damage that matters: the game has one damage model (shield, then armor), so a ship's state comes from its
    -- health ratio (armor + shield against their maximum). The deeper the damage, the slower it flies and turns and
    -- the slower its shield recharges. Each stage is written once when it is crossed (never on every scan), to
    -- constants the game computes once per ship. Fighters and frigates only, enemies and allies; never your ship,
    -- aliens, civilians, cargo, drones or capital ships. Your own ship's damage is not touched.
    -- ON by default. Tested in the game (2026-11-14): stages, one write each, re-applied after a recalculation, restored on repair.
    ShipDamage = {
        Enabled = true,
        Interval = 3.0,   -- seconds between scans
        Enemies = true,
        Allies = true,
        -- Below = health ratio under which the stage applies; Speed, Turn, Shield = multipliers (1 = unchanged).
        -- The deepest stage reached applies (they do not stack). Going back up needs the threshold + 5 %.
        Stages = {
            { Below = 0.66, Speed = 0.85, Turn = 0.85, Shield = 1.0 },
            { Below = 0.50, Speed = 0.85, Turn = 0.85, Shield = 0.5 },
            { Below = 0.33, Speed = 0.65, Turn = 0.65, Shield = 0.5 },
        },
    },

    -- true writes what the mod does to hardcorespacerealism.log (in the mod folder).
    Debug = false,
}
