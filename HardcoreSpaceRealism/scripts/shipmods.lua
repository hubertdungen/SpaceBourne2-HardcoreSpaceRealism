--[[
  Stat multipliers for NPC ships, shared by doctrine.lua (turning) and hull.lua (speed, turning, shield recharge).
  Why a shared module: both write the same constants (ShipBaseTurnSpeed). The game computes these constants
  once per ship (CalculateStats) and may compute them again; if two modules each "re-based" on the other's
  value the numbers would drift. Here each ship has ONE record: the base values as the game wrote them, what we
  last wrote, and one multiplier per source. The value written is always base x all multipliers, and a value
  that is not what we last wrote is taken as the game's new base. A source that stops (multiplier 1) puts the
  base back. Nothing is written when the value is already right.
  Written constants (never the ones the AI rewrites every cycle):
    Speed  = ShipBaseSpeed        Turn = ShipBaseTurnSpeed        Shield = ShieldRechargeRate
]]
local M = {}

local PROPS = { Speed = "ShipBaseSpeed", Turn = "ShipBaseTurnSpeed", Shield = "ShieldRechargeRate" }
local ORDER = { "Speed", "Turn", "Shield" }
local recs, calls = {}, 0

local function same(a, b)
    return math.abs(a - b) <= 0.01 + math.max(math.abs(a), math.abs(b)) * 1e-4
end

--- apply(ship, name, source, factors): factors = { Speed = x, Turn = x, Shield = x } (missing = 1).
--- Returns a short text of what was written ("" when nothing was).
function M.apply(ship, name, source, factors)
    local rec = recs[name]
    if not rec then rec = { base = {}, set = {}, mult = {} }; recs[name] = rec end
    rec.mult[source] = factors
    rec.t = os.clock()
    local did = {}
    for _, key in ipairs(ORDER) do
        local pname = PROPS[key]
        local okR, raw = pcall(function() return ship[pname] end)
        local cur = okR and tonumber(raw) or nil
        if cur and cur > 0 then
            -- first sight, or the game wrote the constant again: that is the new base
            if rec.set[key] == nil or not same(cur, rec.set[key]) then rec.base[key] = cur end
            local f = 1
            for _, m in pairs(rec.mult) do f = f * (m[key] or 1) end
            local want = rec.base[key] * f
            if same(want, cur) then
                rec.set[key] = cur
            else
                local ok = pcall(function() ship[pname] = want end)
                if ok then
                    rec.set[key] = want
                    did[#did + 1] = string.format("%s %.1f -> %.1f", pname, cur, want)
                else
                    rec.set[key] = cur
                end
            end
        end
    end
    calls = calls + 1
    if calls % 300 == 0 then M.gc() end
    return table.concat(did, ", ")
end

function M.forget(name) recs[name] = nil end

--- Drop records of ships not applied to for two minutes (the ship is gone).
function M.gc()
    local t = os.clock()
    for name, rec in pairs(recs) do
        if t - (rec.t or 0) > 120 then recs[name] = nil end
    end
end

return M
