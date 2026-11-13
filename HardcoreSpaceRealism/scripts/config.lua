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
    },

    -- Enemy fighters and frigates by tier. In the game every enemy ends a run with a "close pass": it doubles its
    -- speed and dives at you. Here the low tiers (pirates, and ranks up to LowRank) never do that, so they keep
    -- shooting from their normal attack distance, and they turn a little slower (sloppy). Higher ranks of the
    -- military factions are left as the game has them.
    -- OFF in 0.1.0: written from the game's own logic but not tested in the game yet. Switch it on to try it
    -- (and tell me how it goes); it will be on by default once it has been tested.
    EnemyDoctrine = {
        Enabled = false,
        LowRank = 1,        -- enemy rank (0 = weakest); pirates count as low tier whatever their rank
        SloppyTurn = 0.85,  -- low-tier turn speed x this (1 = unchanged)
        Interval = 3.0,     -- seconds between scans
    },

    -- Allied fighters and frigates (not the capital, cargo or command ships): retreat when badly damaged, and
    -- fight the target you have locked. The game has no retreat: a ship fights until it dies. Retreat uses the
    -- game's own "return to spawn" flag, so the ship flies back to where it came from (your ship when it has no
    -- root) and the game stops it there. Health = armor + shield against their maximum.
    -- OFF in 0.2.0: written from the game's own logic but not tested in the game yet. Switch it on to try it
    -- (and tell me how it goes); it will be on by default once it has been tested.
    AlliedShips = {
        Enabled = false,
        Interval = 3.0,        -- seconds between scans
        Retreat = {
            Enabled = true,
            Below = 0.25,        -- health ratio under which an ally pulls back
            ResumeAbove = 0.6,   -- it rejoins the fight above this (shields recharge by themselves)
            MaxSeconds = 120,    -- it rejoins after this long whatever its health, then waits 60 s before it may retreat again
            MaxDistance = 3000,  -- metres from its root; farther than that it stays in the fight (the game moves a returning ship beyond 4.6 km onto its root)
        },
        ShareTarget = {
            Enabled = true,      -- allies outside a squad attack the target you have locked (once per new target)
            Range = 20000,       -- metres: only allies this close to you are told
        },
    },

    -- Planned, not yet in (see DESIGN.md): ShipDamage (hull states, 0.3.0).

    -- true writes what the mod does to hardcorespacerealism.log (in the mod folder).
    Debug = false,
}
