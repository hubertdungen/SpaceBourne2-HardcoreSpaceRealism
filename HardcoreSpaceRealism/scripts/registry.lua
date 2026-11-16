--[[
  registry.lua (Hardcore Space Realism 0.4.1) - the ships and the rescue pods this mod works on, without ever searching the world.

  0.4.0 found them with FindAllOf on 3 s / 2.5 s timers. FindAllOf walks the whole object array of the game (50 to
  70 ms; HTR's 0.3.1 measured 630 ms on a big world), so a short frame drop came every 3 seconds, on foot too (user
  report 2026-11-16). Now every ship and every pod reports itself from the game's own calls on it, the way Ground
  Waypoints and Hardcore Tactical Realism do:

    ships  Base_Frigate_C (the fighters and frigates, Master_Enemy_C children with the flight AI)
             ReceiveBeginPlay  once, when the ship appears
             CustomEvent_4     the ship's own 1 s behaviour timer (BehSelectTimer, K2_SetTimerDelegate(..., 1.0, looping)):
                               it adds a ship the BeginPlay hook missed (one that appeared before the hook, or whose
                               class does not call the parent's BeginPlay). A table lookup, nothing more.
    pods   MasterPod_C ReceiveBeginPlay.

  No per-frame hook: a Lua call per ship per frame would cost more than it saves. The hooks only store the object and its
  address. Everything else (names, reads, writes) happens later, on the gametick timer, a few ships per call:
  Reg.slice() hands a module the next few ships, so each ship is visited about once per Interval and no frame does all of
  them. An entry is dropped when its object is no longer valid (same address check as HTR); dead and being-destroyed
  ships are skipped. On foot (no ship pawn) the modules' timers return at once.

  The one scan left: when a class is hooked for the first time (the first ClientRestart after its class is loaded) the
  ships that exist already are found with ONE FindAllOf, from a gametick job, not from the hook. That is a load or a ship
  boarding, not a repeating timer. A class that is not loaded yet is tried again only at the next possession
  (ClientRestart: a load, boarding or leaving a ship), never on a timer: a miss costs one ~37 ms lookup and must land in
  a transition, not during play. So if the frigate class loads only later in flight, the ships stay unseen until the next
  possession (the log shows every attempt and seed with its time and cost).
]]
local U = require("shiputil")

local R = { SLICE = 0.5 }  -- seconds between the modules' slice jobs

local MAX_SLICE = 10  -- ships one module handles in one call
local KINDS = {
    ships = { class = "/Game/1Data/Enemy/1__Fighters/Base_Frigate.Base_Frigate_C", short = "Base_Frigate_C",
              hooks = { { "ReceiveBeginPlay", true }, { "CustomEvent_4", false } } },  -- { function, required }
    pods = { class = "/Game/1Data/Enemy/1_Pod/MasterPod.MasterPod_C", short = "MasterPod_C",
             hooks = { { "ReceiveBeginPlay", true } } },
}

local sets = {}      -- kind -> { arr = {entry...}, idx = { [addr] = i } }
for kind in pairs(KINDS) do sets[kind] = { arr = {}, idx = {} } end
local dropped = {}   -- listeners: fn(kind, entry)
local stats = { added = 0, dropped = 0, seeded = 0, seedMs = 0 }

local function entryValid(e)
    local ok, v = pcall(function() return e.obj:IsValid() end)
    if not ok or v ~= true then return false end
    local okA, a = pcall(function() return e.obj:GetAddress() end)
    return okA and a == e.addr
end

local function add(kind, obj)
    local S = sets[kind]
    local okA, a = pcall(function() return obj:GetAddress() end)
    if not okA or not a or S.idx[a] then return false end
    local arr = S.arr
    arr[#arr + 1] = { obj = obj, addr = a, t = os.clock() }
    S.idx[a] = #arr
    stats.added = stats.added + 1
    return true
end

local function remove(kind, i)
    local S = sets[kind]
    local arr = S.arr
    local e = arr[i]
    if not e then return end
    local last = arr[#arr]
    arr[i] = last
    arr[#arr] = nil
    S.idx[e.addr] = nil
    if last ~= e then S.idx[last.addr] = i end
    stats.dropped = stats.dropped + 1
    for _, fn in ipairs(dropped) do pcall(fn, kind, e) end
end

--- fn(kind, entry) when an entry is dropped (its object is gone): modules forget what they kept for e.name.
function R.onDrop(fn) dropped[#dropped + 1] = fn end

--- Entry count of a kind.
function R.count(kind) return #sets[kind].arr end

--- The full name of an entry's object (read once, on first use; nil if it cannot be read).
function R.name(e)
    if e.name == nil then
        local ok, n = pcall(function() return e.obj:GetFullName() end)
        e.name = ok and n or false
    end
    return e.name or nil
end

--- Is the player in a ship (a pawn with a captive list)? Cached for 0.4 s; false on foot and in menus.
local shipT, shipV = -1e9, false
function R.inShip()
    local t = os.clock()
    if t - shipT >= 0.4 then shipT = t; shipV = U.playerShip() ~= nil end
    return shipV
end

--- All valid objects of a kind (pods are few; ships when a pod is past its grace window). Drops the invalid ones.
function R.objs(kind)
    local out, arr = {}, sets[kind].arr
    local i = 1
    while i <= #arr do
        if entryValid(arr[i]) then
            out[#out + 1] = arr[i].obj
            i = i + 1
        else
            remove(kind, i)  -- the last entry now sits at i: look at it next
        end
    end
    return out
end

--- Calls fn(obj, name) for the next few living ships/pods after `cur` (the module's own cursor table), so that every
--- entry is visited about once per `interval` seconds when this is called every R.SLICE seconds. Errors in fn are caught.
function R.slice(kind, cur, interval, fn)
    local arr = sets[kind].arr
    local total = #arr
    if total == 0 then return end
    local n = math.max(1, math.min(MAX_SLICE, math.ceil(total * R.SLICE / math.max(0.5, interval))))
    local done = 0
    while done < n and #arr > 0 and done < #arr do
        local i = (cur.i or 0) + 1
        if i > #arr then i = 1 end
        local e = arr[i]
        if entryValid(e) then
            cur.i = i
            done = done + 1
            if U.alive(e.obj) then
                local name = R.name(e)
                if name then pcall(fn, e.obj, name) end
            end
        else
            remove(kind, i)
            cur.i = i - 1
        end
    end
end

-- Hooks ---------------------------------------------------------------------------------------------------------------
local GT, log, warn
local pending = {}   -- kind -> true: hooked, the existing ones still to be found once

local function hookKind(kind)
    local k = KINDS[kind]
    if k.done then return true end
    local t0 = os.clock()
    local okC, cls = pcall(StaticFindObject, k.class)
    local found = okC and cls and cls:IsValid()
    log(string.format("registry: attempt at %.1f s: %s %s (%.1f ms)", t0, k.short, found and "loaded" or "not loaded yet",
        (os.clock() - t0) * 1000))
    if not found then return false end
    local all = true
    k.hooked = k.hooked or {}
    for _, h in ipairs(k.hooks) do
        local fname, required = h[1], h[2]
        if not k.hooked[fname] then
            local ok, err = pcall(RegisterHook, k.class .. ":" .. fname, function(self)
                local okG, o = pcall(self.get, self)
                if okG and o then add(kind, o) end
            end)
            if ok then k.hooked[fname] = true; log("registry: hooked " .. k.short .. ":" .. fname)
            elseif required then all = false; warn("registry: could not hook " .. k.short .. ":" .. fname .. ": " .. tostring(err))
            else log("registry: optional hook " .. k.short .. ":" .. fname .. " not available: " .. tostring(err)) end
        end
    end
    if all then k.done = true; pending[kind] = true end
    return all
end

-- the one-off search for what existed before the hook (from a gametick job, never from the hook itself)
local function seed()
    for kind in pairs(pending) do
        pending[kind] = nil
        local t0 = os.clock()
        local ok, list = pcall(FindAllOf, KINDS[kind].short)
        local n = 0
        if ok and list then for _, o in ipairs(list) do if add(kind, o) then n = n + 1 end end end
        local ms = (os.clock() - t0) * 1000
        stats.seeded, stats.seedMs = stats.seeded + n, stats.seedMs + ms
        log(string.format("registry: seed at %.1f s: found %d existing %s with one FindAllOf (%.1f ms)", t0, n, KINDS[kind].short, ms))
    end
end

-- Only from R.boot (a possession): no timed retries.
local function attempt()
    for kind in pairs(KINDS) do hookKind(kind) end
    if next(pending) then GT.after(0.5, seed) end
end

--- init(GT, log, warn): call once at load; then call R.boot() from GT.boot's callback (every load / possession).
function R.init(gt, logf, warnf)
    GT, log, warn = gt, logf, warnf
end

--- After each load or possession (ClientRestart): hook the classes that have just become available.
function R.boot()
    if not GT then return end
    local pendingTry = false
    for kind in pairs(KINDS) do if not KINDS[kind].done then pendingTry = true end end
    if pendingTry then attempt() end
end

function R.report()
    return string.format("registry: %d ships, %d pods; added %d, dropped %d, found by the one-off search %d (%.0f ms)",
        #sets.ships.arr, #sets.pods.arr, stats.added, stats.dropped, stats.seeded, stats.seedMs)
end

return R
