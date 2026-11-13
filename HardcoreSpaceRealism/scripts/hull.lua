--[[
  NPC hull states (Hardcore Space Realism 0.3.0, OFF by default until tested in game).
  The game has one damage model for ships: shield, then armor, no engine, weapon or shield parts (only capital
  ships have parts and they are left alone). So a ship's "state" here comes from its hull ratio
  (CurrentArmor + CurrentShield) / (MaxArmor + MaxShield). Each stage multiplies constants the game computes once
  per ship (never the ones the AI rewrites every cycle), through shipmods.lua:
      ShipBaseSpeed (engines)   ShipBaseTurnSpeed (turning)   ShieldRechargeRate (shield recharge)
  Stages (all settings in config.lua, cumulative stages are not stacked: the deepest stage reached applies):
      below 66 %: engines and turning x0.85
      below 50 %: and shield recharge x0.5
      below 33 %: engines and turning x0.65
  A stage is written once when it is crossed, not on every scan. Going back up (shields recharge) needs
  the stage's threshold + 5 % to step down. A value the game rewrites (new CalculateStats) is taken as the new
  base and the stage is applied again to it.
  Not touched: the player's ship, aliens, civilians, cargo, drones, capital ships, fleet generals (shiputil.kind).
  No hooks (Damage1 / ReceiveAnyDamage run per hit): the ratio is polled on the timer. Not locational.
]]
local U = require("shiputil")
local Mods = require("shipmods")

local H = {}
local HYST = 0.05

local function num(v, default, lo, hi)
    v = tonumber(v)
    if not v then v = default end
    return math.max(lo, math.min(hi, v))
end

-- Default stages, deepest last. Below = hull ratio under which the stage applies.
local DEFAULT_STAGES = {
    { Below = 0.66, Speed = 0.85, Turn = 0.85, Shield = 1.0 },
    { Below = 0.50, Speed = 0.85, Turn = 0.85, Shield = 0.5 },
    { Below = 0.33, Speed = 0.65, Turn = 0.65, Shield = 0.5 },
}

--- start(GT, cfg, log, warn): cfg = { Enabled, Interval, Enemies, Allies, Stages = { {Below, Speed, Turn, Shield}, ... } }
function H.start(GT, cfg, log, warn)
    if not cfg.Enabled then log("ship damage off in config.lua") return end
    local stages = {}
    local src = type(cfg.Stages) == "table" and #cfg.Stages > 0 and cfg.Stages or DEFAULT_STAGES
    for _, sg in ipairs(src) do
        if type(sg) == "table" then
            stages[#stages + 1] = {
                Below = num(sg.Below, 0.5, 0.02, 0.98),
                Speed = num(sg.Speed, 1, 0.2, 1),
                Turn = num(sg.Turn, 1, 0.2, 1),
                Shield = num(sg.Shield, 1, 0.1, 1),
            }
        end
    end
    table.sort(stages, function(a, b) return a.Below > b.Below end)   -- shallowest (highest ratio) first
    local enemiesOn, alliesOn = cfg.Enemies ~= false, cfg.Allies ~= false
    local recs = {}   -- full name -> { stage }
    local changes = 0

    local function stageFor(h, cur)
        local target = 0
        for i, sg in ipairs(stages) do if h < sg.Below then target = i end end
        if target > cur then return target end
        if target < cur and h >= stages[cur].Below + HYST then return target end
        return cur
    end

    local lastCount = -1
    local function tick()
        local ships = U.frigates()
        local cur, n = {}, 0
        for _, s in ipairs(ships) do
            local kind = U.kind(s)
            if (kind == "enemy" and enemiesOn) or (kind == "ally" and alliesOn) then
                local name = U.fullName(s)
                local h = name and U.health(s)
                if h then
                    cur[name] = true
                    n = n + 1
                    local rec = recs[name]
                    if not rec then rec = { stage = 0 }; recs[name] = rec end
                    local new = stageFor(h, rec.stage)
                    local changed = new ~= rec.stage
                    rec.stage = new
                    -- ships never damaged are never touched; a ship that has a stage is re-checked every scan so
                    -- that a value the game rewrote is put back (shipmods keeps the game's value as the base)
                    if new > 0 or rec.applied then
                        local sg = stages[new]
                        local f = sg and { Speed = sg.Speed, Turn = sg.Turn, Shield = sg.Shield } or {}
                        local did = Mods.apply(s, name, "hull", f)
                        rec.applied = true
                        if did ~= "" or changed then
                            if changed then changes = changes + 1 end
                            log(string.format("hull %s (%s) at %.0f %%: stage %d%s", U.shortName(name), kind, h * 100, new,
                                did ~= "" and (": " .. did) or ""))
                        end
                    end
                end
            end
        end
        for name in pairs(recs) do
            if not cur[name] then recs[name] = nil; Mods.forget(name) end
        end
        if n ~= lastCount then
            lastCount = n
            log(string.format("hull states: %d ships watched, %d stage changes so far", n, changes))
        end
    end

    local interval = math.max(1, tonumber(cfg.Interval) or 3)
    GT.every(interval, function()
        local ok, err = pcall(tick)
        if not ok then warn("hull tick: " .. tostring(err)) end
    end)
    local parts = {}
    for i, sg in ipairs(stages) do
        parts[#parts + 1] = string.format("<%.0f%%: speed x%.2f turn x%.2f shield x%.2f", sg.Below * 100, sg.Speed, sg.Turn, sg.Shield)
    end
    log(string.format("ship damage on: enemies %s, allies %s, every %.1f s; %s", enemiesOn and "yes" or "no",
        alliesOn and "yes" or "no", interval, table.concat(parts, "; ")))
end

return H
