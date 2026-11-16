--[[
  Smarter allied ships (Hardcore Space Realism 0.2.0; ON by default with retreat only since the in-game test, shared target OFF).
  Allied fighters and frigates (Master_Enemy_C with AITypes 1, found as Base_Frigate_C) get two things:

  1. Retreat when badly damaged. The game has no retreat: a ship fights until it dies. The game does have the
     flag Master_Enemy.ReturnToSpawn, which it sets itself when a ship strays too far from its spawn root: the
     ship then flies to SpawnRoot (the player's ship when there is no root), the game clears the flag within
     50 m of it, and a ship more than 4.6 km away is moved onto the root. We use that same flag (not ChangeState,
     whose state switch is native). Health ratio = (CurrentArmor + CurrentShield) / (MaxArmor + MaxShield).
       - below Retreat.Below (25 %) and not more than Retreat.MaxDistance from the root: flag set;
       - while retreating, a flag the game has cleared (it arrived) is set again, so the ship stays back;
       - released (flag cleared by us) when the ratio is back above Retreat.ResumeAbove (60 %, shields recharge
         by themselves), or after Retreat.MaxSeconds, then a 60 s pause before it may retreat again.
     Never: the player's ship, enemies, aliens, civilians, cargo, drones, capital ships (other classes or types).
  2. Shared target. An ally that is not in a squad (squad members already copy their leader) and not retreating
     is pointed at the player's locked target with the game's own Master_Enemy:SetOrderAttackTargetFromTacticMap
     (sets MainTarget, calls TargetIsChanged, marks the target as ordered), once per new target.

  Cost: the shared one-second ship scan (shiputil.lua) every Interval seconds; reads per ally; writes only when
  a threshold is crossed or a target changes. No hooks.
]]
local U = require("shiputil")

local A = {}

local COOLDOWN = 60  -- seconds an ally that was released by timeout waits before it may retreat again

local function num(v, default, lo, hi)
    v = tonumber(v)
    if not v then v = default end
    return math.max(lo, math.min(hi, v))
end

--- start(GT, cfg, log, warn): cfg = { Enabled, Interval, Retreat = {...}, ShareTarget = {...} }
function A.start(GT, cfg, log, warn)
    if not cfg.Enabled then log("allied ships off in config.lua") return end
    local rt = type(cfg.Retreat) == "table" and cfg.Retreat or {}
    local sh = type(cfg.ShareTarget) == "table" and cfg.ShareTarget or {}
    local retreatOn = rt.Enabled ~= false
    local shareOn = sh.Enabled == true   -- off unless switched on: see DESIGN.md section 3 (run 2)
    local below = num(rt.Below, 0.25, 0.05, 0.9)
    local resume = math.max(below + 0.1, num(rt.ResumeAbove, 0.6, 0.15, 1.0))
    local maxSec = num(rt.MaxSeconds, 120, 10, 1800)
    local maxDist2 = (num(rt.MaxDistance, 3000, 200, 4000) * 100) ^ 2   -- metres -> UE units (cm); the game moves ships beyond 4.6 km
    local shareRange2 = (num(sh.Range, 20000, 500, 200000) * 100) ^ 2

    local recs = {}      -- ally full name -> { retreating, since, cool, target }
    local retreats, shares = 0, 0

    local function setFlag(ship, v)
        return pcall(function() ship.ReturnToSpawn = v end)
    end

    local function retreatStep(s, name, rec, h, now, player)
        if rec.retreating then
            if h >= resume then
                setFlag(s, false)
                rec.retreating = false
                log(string.format("ally %s back in the fight at %.0f %%", U.shortName(name), h * 100))
            elseif now - rec.since > maxSec then
                setFlag(s, false)
                rec.retreating, rec.cool = false, now + COOLDOWN
                log(string.format("ally %s retreat timed out at %.0f %%", U.shortName(name), h * 100))
            elseif U.prop(s, "ReturnToSpawn", false) ~= true then
                setFlag(s, true)   -- it arrived and the game cleared the flag: keep it back
            end
            return
        end
        if h >= below or (rec.cool and now < rec.cool) then return end
        local root = U.prop(s, "SpawnRoot", nil)
        if not U.valid(root) then root = player end
        local a, b = U.loc(s), root and U.loc(root)
        if not a or not b then return end
        if U.dist2(a, b) > maxDist2 then return end   -- too far: the game would move it onto the root
        if setFlag(s, true) then
            rec.retreating, rec.since = true, now
            retreats = retreats + 1
            log(string.format("ally %s retreats at %.0f %% (%.1f km from its root)", U.shortName(name), h * 100,
                math.sqrt(U.dist2(a, b)) / 100000))
        end
    end

    local function shareStep(s, name, rec, lt, ltName, pl)
        if rec.target == ltName then return end
        if U.prop(s, "HasSquad?", false) == true then return end
        local a = U.loc(s)
        if not a or U.dist2(a, pl) > shareRange2 then return end
        local ok = pcall(function() s:SetOrderAttackTargetFromTacticMap(lt) end)
        if ok then
            rec.target = ltName
            shares = shares + 1
            log(string.format("ally %s told to attack %s", U.shortName(name), U.shortName(ltName)))
        end
    end

    local lastCount = -1
    local function tick()
        local ships = U.frigates()
        if not ships then return end   -- on foot: no scan, records kept
        local now = os.clock()
        local player = U.playerShip()
        local lt, ltName, pl
        if shareOn and player then
            local t = U.prop(player, "LockedTarget", nil)
            if U.alive(t) and U.num(t, "AITypes", -1) == U.AI_ENEMY and U.prop(t, "Dead?", false) ~= true then
                lt, ltName, pl = t, U.fullName(t), U.loc(player)
            end
        end
        local cur, n = {}, 0
        for _, s in ipairs(ships) do
            if U.kind(s) == "ally" then
                local name = U.fullName(s)
                if name then
                    cur[name] = true
                    n = n + 1
                    local rec = recs[name]
                    if not rec then rec = {}; recs[name] = rec end
                    local h = U.health(s)
                    if retreatOn and h then retreatStep(s, name, rec, h, now, player) end
                    if shareOn and lt and ltName and pl and not rec.retreating then shareStep(s, name, rec, lt, ltName, pl) end
                end
            end
        end
        for name in pairs(recs) do if not cur[name] then recs[name] = nil end end
        if n ~= lastCount then
            lastCount = n
            log(string.format("allied ships: %d tracked, %d retreats, %d target orders so far", n, retreats, shares))
        end
    end

    local interval = math.max(1, tonumber(cfg.Interval) or 3)
    GT.every(interval, function()
        local ok, err = pcall(tick)
        if not ok then warn("allies tick: " .. tostring(err)) end
    end)
    log(string.format("allied ships on: retreat %s (below %.0f %%, back above %.0f %%, max %.0f s), shared target %s, every %.1f s",
        retreatOn and "on" or "off", below * 100, resume * 100, maxSec, shareOn and "on" or "off", interval))
end

return A
