--[[
  Helpers shared by the ship modules (allies.lua, hull.lua). Read-only: nothing here writes to the game.
  One scan of the fighters and frigates (FindAllOf "Base_Frigate_C") is shared by all modules for one second,
  so several modules on the same timer cost one scan. Bombers, drones, capital ships, carriers and the
  player's ship are other classes and are never in this list.
]]
local U = {}

local SHIP, CONTROLLER = "Base_Frigate_C", "Q1Controller_C"
U.AI_ENEMY, U.AI_ALLY = 0, 1
U.FACTION_ALIENS = 4
-- Ship_Types values the ship modules work on: 0 Frigate, 1 Fly (fighters), 12 HeavyFighter. Cargo, carriers,
-- dreadnoughts, capitals, explorers, civilians, drone nests, command, captain and mother ships are left alone.
local ALLOWED_TYPE = { [0] = true, [1] = true, [12] = true }

function U.valid(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v == true
end

function U.prop(o, name, default)
    local ok, v = pcall(function() return o[name] end)
    if ok and v ~= nil then return v end
    return default
end

function U.num(o, name, default)
    return tonumber(U.prop(o, name, default)) or default
end

function U.loc(o)
    local ok, v = pcall(function() return o:K2_GetActorLocation() end)
    if ok and v and v.X then return { X = v.X, Y = v.Y, Z = v.Z } end
    return nil
end

function U.dist2(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return dx * dx + dy * dy + dz * dz
end

function U.fullName(o)
    local ok, n = pcall(function() return o:GetFullName() end)
    if ok then return n end
    return nil
end

function U.shortName(name)
    return (tostring(name):gsub("^.*%.", ""))
end

-- A destroyed actor stays valid until garbage collection and reports the origin (see podcatch.lua).
function U.alive(o)
    if not U.valid(o) then return false end
    local ok, dying = pcall(function() return o:IsActorBeingDestroyed() end)
    if ok and dying == true then return false end
    local okL, l = pcall(function() return o:K2_GetActorLocation() end)
    if okL and l and l.X == 0 and l.Y == 0 and l.Z == 0 then return false end
    return true
end

-- The player's ship: the pawn of the controller (on foot it is a character without a captive list: nil).
function U.playerShip()
    local pc = FindFirstOf(CONTROLLER)
    if not U.valid(pc) then return nil end
    local ok, pawn = pcall(function() return pc.Pawn end)
    if not ok or not U.valid(pawn) then return nil end
    if U.prop(pawn, "Captives", nil) == nil then return nil end
    return pawn
end

-- Living fighters and frigates, scanned at most once a second (shared between modules).
local cache, cacheT = {}, -1e9
function U.frigates()
    local t = os.clock()
    if t - cacheT < 1.0 then return cache end
    local out = {}
    local ok, list = pcall(FindAllOf, SHIP)
    if ok and list then
        for _, s in ipairs(list) do
            if U.alive(s) then out[#out + 1] = s end
        end
    end
    cache, cacheT = out, t
    return out
end

--- "enemy" or "ally" for the ships the ship modules may touch, nil for everything else: the dead, creatures,
--- non-combat ships, character shooters, fleet generals, aliens, civilians and the ship types left alone.
function U.kind(s)
    if U.prop(s, "Dead?", false) == true or U.prop(s, "Creature?", false) == true
        or U.prop(s, "Non_combat_Ship", false) == true or U.prop(s, "CharacterShooter?", false) == true
        or U.prop(s, "General?", false) == true then
        return nil
    end
    if not ALLOWED_TYPE[U.num(s, "ShipType", -1)] then return nil end
    local ai = U.num(s, "AITypes", -1)
    if ai == U.AI_ALLY then return "ally" end
    if ai == U.AI_ENEMY and U.num(s, "Faction", -1) ~= U.FACTION_ALIENS then return "enemy" end
    return nil
end

--- Hull ratio 0..1: (CurrentArmor + CurrentShield) / (MaxArmor + MaxShield). nil while the ship has no stats yet.
function U.health(s)
    local mx = U.num(s, "MaxArmor", 0) + U.num(s, "MaxShield", 0)
    if mx <= 0 then return nil end
    local h = (U.num(s, "CurrentArmor", 0) + U.num(s, "CurrentShield", 0)) / mx
    if h < 0 then h = 0 elseif h > 1 then h = 1 end
    return h
end

return U
