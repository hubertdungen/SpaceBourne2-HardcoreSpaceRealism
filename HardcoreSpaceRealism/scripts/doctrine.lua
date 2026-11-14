--[[
  Enemy doctrine by tier (Hardcore Space Realism, in since 0.1.0; ON by default since the in-game test of 2026-11-14).

  The game's enemy fighters and frigates (Base_Frigate_C) fly a "close pass": when the target is nearer than
  CloseTrueBeheviur x RangeMultipler they set Close? = true, double their speed, halve their turning and dive at a
  point 400 m from the target, until they are CloseBoolDistance away again. Every enemy does it, pirates and
  elite crews alike.

  Here the low tiers (pirates, and ranks up to LowRank) never start that pass: their CloseTrueBeheviur is set to 0,
  so they keep flying their normal attack moves at normal speed (the game's own band AttackDistMin..AttackDistMax),
  and they turn a little slower (sloppy: ShipBaseTurnSpeed x SloppyTurn). Higher ranks of the military factions
  are left as the game has them. Never touched: allied ships (AITypes 1), aliens, ships with no faction, the player's
  own faction (Earthling), creatures, non-combat ships.

  Only constants are written: CloseTrueBeheviur is never written by the game; ShipBaseTurnSpeed is written when the
  game calculates the ship's stats, so it goes through shipmods.lua (shared with hull.lua): base x multipliers,
  checked again every scan and re-applied if the game changed it.
  Nothing the AI rewrites every cycle (SpeedMultipler, TurnSpeedMultipler, RangeMultipler...) is touched.
  Cost: one FindAllOf per scan on the gametick timer; a few property reads per ship; writes only when needed.
]]
local Mods = require("shipmods")
local D = {}

local SHIP = "Base_Frigate_C"
local AI_ENEMY = 0
local FACTION_PIRATES = 3
local FACTION_SKIP = { [4] = true, [5] = true, [6] = true }  -- Aliens, None, Earthling (the player's faction)

local function valid(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v == true
end

local function prop(o, name, default)
    local ok, v = pcall(function() return o[name] end)
    if ok and v ~= nil then return v end
    return default
end

-- a destroyed actor stays valid until garbage collection and reports the origin (see podcatch.lua)
local function alive(o)
    if not valid(o) then return false end
    local ok, dying = pcall(function() return o:IsActorBeingDestroyed() end)
    if ok and dying == true then return false end
    local okL, l = pcall(function() return o:K2_GetActorLocation() end)
    if okL and l and l.X == 0 and l.Y == 0 and l.Z == 0 then return false end
    return true
end

--- start(GT, cfg, log, warn): cfg = { Enabled, LowRank, SloppyTurn, Interval }
function D.start(GT, cfg, log, warn)
    if not cfg.Enabled then log("enemy doctrine off in config.lua") return end
    local lowRank = math.floor(tonumber(cfg.LowRank) or 1)
    local sloppy = math.max(0.3, math.min(1.0, tonumber(cfg.SloppyTurn) or 0.85))
    local seen = {}  -- full name -> true (ships tracked; the turn values live in shipmods.lua)
    local touched, lastCount = 0, -1

    -- Factions (enum Factions): 0 Morthra, 1 Falron, 2 Xeghan (the military factions), 3 Pirates, 4 Aliens, 5 None,
    -- 6 Earthling (the player's own faction). Left as the game flies them: aliens, no faction and the player's faction.
    local function isLowTier(ship)
        local faction = prop(ship, "Faction", -1)
        if FACTION_SKIP[faction] then return false end
        if faction == FACTION_PIRATES then return true end
        local rank = prop(ship, "Enemy_Rank", 99)
        return rank <= lowRank
    end

    local function tick()
        local ships = FindAllOf(SHIP)
        if not ships or #ships == 0 then return end
        local cur = {}
        for _, s in ipairs(ships) do
            if alive(s) and prop(s, "AITypes", -1) == AI_ENEMY and prop(s, "Dead?", false) ~= true
                and prop(s, "Creature?", false) ~= true and prop(s, "Non_combat_Ship", false) ~= true
                and prop(s, "CharacterShooter?", false) ~= true and isLowTier(s) then
                local okN, name = pcall(function() return s:GetFullName() end)
                if okN then
                    cur[name] = true
                    seen[name] = true
                    local close0 = prop(s, "CloseTrueBeheviur", 0)
                    local did = {}
                    if close0 > 0 then
                        local ok = pcall(function() s.CloseTrueBeheviur = 0 end)
                        if ok then did[#did + 1] = string.format("close pass off (was %.0f)", close0) end
                    end
                    -- turn: base x multipliers; the game's own value is the base, re-read when the game
                    -- recalculated the ship's stats and replaced our value
                    local turned = Mods.apply(s, name, "doctrine", { Turn = sloppy })
                    if turned ~= "" then did[#did + 1] = turned end
                    if #did > 0 then
                        touched = touched + 1
                        log(string.format("doctrine %s faction %s rank %s level %s: %s",
                            (name:gsub("^.*%.", "")), tostring(prop(s, "Faction", "?")), tostring(prop(s, "Enemy_Rank", "?")),
                            tostring(prop(s, "Level", "?")), table.concat(did, ", ")))
                    end
                end
            end
        end
        for name in pairs(seen) do if not cur[name] then seen[name] = nil end end
        local n = 0
        for _ in pairs(cur) do n = n + 1 end
        if n ~= lastCount then lastCount = n; log("doctrine: " .. n .. " low-tier enemy ships tracked, " .. touched .. " changes so far") end
    end

    local interval = math.max(1, cfg.Interval or 3)
    GT.every(interval, function()
        local ok, err = pcall(tick)
        if not ok then warn("doctrine tick: " .. tostring(err)) end
    end)
    log(string.format("enemy doctrine on: low tier = pirates or rank <= %d, turn x%.2f, every %.1f s", lowRank, sloppy, interval))
end

return D
