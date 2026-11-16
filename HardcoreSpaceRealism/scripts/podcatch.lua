--[[
  Pod catchers for allies (moved here from Bigger Armies 0.2.0; grace window and faction credit added in HSR 0.4.0).

  The game gives the pod catcher to the player only: the item "Use_PodCatcher" and the mothership perk
  "Mother Pod Catcher" (Q1_Master_Ship:MotherPodCatcher, every 10 s it takes a free pod and calls the
  pod's own CatchByMother). Allied ships catch nothing, so rescue pods drift away or time out.

  Here: every few seconds on the game thread (gametick.lua, no LoopAsync), find the free pods
  (MasterPod_C, tag "FreePod"). A pod is tracked from the first scan that sees it free and started; only after
  it has been free for GraceSeconds may an ally take it, so YOU get the first chance (a pod caught, destroyed or no
  longer free is forgotten). Then a pod that is closer to an allied ship than to you is taken, in one of two ways
  (PodCatchers.Credit):

  "player" (tested): inside PodCatchers.Range of that ship, the game's own MasterPod:CatchByMother(ally
      ship): the pod flies to the ally, the game's own drone cable animation plays and the pilot lands in YOUR
      captives (Q1_Master_Ship.Captives), exactly like your own catch. Not done when your captive slots are full.
      The pod's own catch flow ends in Ship.AddCaptive on the player's ship whoever "the mother" is (read in the
      Blueprint), so this is the only credit the game's catch can give.
  "faction" (DEFAULT, tested in the game 2026-11-14): no captive. An ally within PodCatchers.FactionRange of the pod picks
      it up: your faction gets FactionPowerPerPilot Faction Power (Game_Builder "Add Remove Faction Power", the
      call the Faction Power mod uses) and the pod is removed. Your captive slots are not used and not needed.

  Not done in either mode when: the mothership perk is on (it already takes every free pod), the pod is not
  started yet or already being caught. Cost: one FindAllOf per tick; the ship scan only runs while a pod is
  past its grace window.
]]

local U = require("shiputil")

local P = {}

local POD, ALLY_SHIP, CONTROLLER = "MasterPod_C", "Master_Enemy_C", "Q1Controller_C"
local AI_ALLY = 1
local FLIGHT = 12  -- seconds a caught pod needs to reach the ship; counts against the free captive slots
local REMEMBER = 90 -- seconds a pod we caught stays on the "already caught" list
local ADD_POWER = "Add Remove Faction Power" -- Game_Builder: (Amount:Int, out Success?, out CurrentPower)

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

-- Destroyed actors stay valid for IsValid() until the garbage collector runs: they keep their tags and report
-- the world origin as their place (test 2026-11-13: a destroyed pod and a destroyed ally "0.0 km" apart were
-- caught again and again). So: not being destroyed, and not sitting exactly on the origin.
local function alive(o)
    if not valid(o) then return false end
    local ok, dying = pcall(function() return o:IsActorBeingDestroyed() end)
    if ok and dying == true then return false end
    local okL, l = pcall(function() return o:K2_GetActorLocation() end)
    if okL and l and l.X == 0 and l.Y == 0 and l.Z == 0 then return false end
    return true
end

local function hasTag(pod, tag)
    local ok, tags = pcall(function() return pod.Tags end)
    if not ok or tags == nil then return false end
    local found = false
    pcall(function()
        tags:ForEach(function(_, e)
            local okS, s = pcall(function() return e:get():ToString() end)
            if okS and s == tag then found = true end
        end)
    end)
    return found
end

-- Your ship: the pawn of the player controller (FindFirstOf on the ship class also returns other objects of
-- the class, with no captive list). On foot the pawn is a character, which has no Captives: nothing to do.
-- (0.4.1: through shiputil, with the controller kept instead of looked up on every call.)
local function playerShip()
    return U.playerShip()
end

-- Game_Builder (the faction's data and Power), reached through the player controller like the Faction Power mod does.
local function gameBuilder()
    local pc = U.controller()
    if not pc then return nil end
    local b = prop(pc, "GameBuilderRef", nil)
    if valid(b) then return b end
    return nil
end

local function dist2(a, b)
    local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
    return dx * dx + dy * dy + dz * dz
end

local function loc(o)
    local ok, v = pcall(function() return o:K2_GetActorLocation() end)
    if ok and v and v.X then return { X = v.X, Y = v.Y, Z = v.Z } end
    return nil
end

--- start(GT, cfg, log, warn): cfg = { Enabled, Range (m), Interval (s), GraceSeconds, Credit, FactionRange (m), FactionPowerPerPilot }
function P.start(GT, cfg, log, warn)
    if not cfg.Enabled then log("pod catchers off in config.lua") return end
    local range2 = (cfg.Range * 100) ^ 2 -- metres -> UE units (cm)
    local recent = {}                   -- os.clock() of the last catches (slots in flight)
    local lastFull = false
    local caught, credited = 0, 0
    local warnedPower = false
    local lastNote = {}                  -- pod name -> os.clock() of the last "waits" note
    local done = {}                      -- full name of a pod we took -> os.clock(): never taken twice
    local firstSeen = {}                 -- full name of a free, started pod -> os.clock() of the first scan that saw it free

    local function tick()
        -- read each scan from the live config table, so the test kit can switch the credit mode in one launch
        local grace = math.max(0, math.min(120, tonumber(cfg.GraceSeconds) or 8))
        local faction = (cfg.Credit == "faction")
        local fRange2 = ((tonumber(cfg.FactionRange) or 1000) * 100) ^ 2
        local fPower = math.max(1, math.floor(tonumber(cfg.FactionPowerPerPilot) or 50))
        local t0 = os.clock()
        -- 0.4.1: nothing to do (and no scan of the whole object array) unless the player is in a ship: the allies only
        -- take pods for a ship pilot, and the pods' grace clocks start when the player is back in the ship
        local ship = playerShip()
        if not ship then return end
        local pods = FindAllOf(POD)
        if not pods or #pods == 0 then firstSeen = {}; return end
        for name, t in pairs(done) do if t0 - t > REMEMBER then done[name] = nil end end
        local free, seen = {}, {}
        for _, pod in ipairs(pods) do
            if alive(pod) and prop(pod, "Started", false) == true and prop(pod, "PodSpawned", false) ~= true
                and hasTag(pod, "FreePod") then
                local okN, name = pcall(function() return pod:GetFullName() end)
                if okN and not done[name] then
                    seen[name] = true
                    if not firstSeen[name] then firstSeen[name] = t0 end
                    if t0 - firstSeen[name] >= grace then free[#free + 1] = { actor = pod, name = name } end
                end
            end
        end
        for name in pairs(firstSeen) do if not seen[name] then firstSeen[name] = nil end end  -- caught, destroyed or no longer free
        if #free == 0 then return end

        if prop(ship, "MoahterPodCathcerActive", false) == true then return end -- the perk takes every free pod

        local now = os.clock()
        local used, max = 0, 0
        if not faction then
            local kept = {}
            for _, t in ipairs(recent) do if now - t < FLIGHT then kept[#kept + 1] = t end end
            recent = kept
            used = #recent
            local okC, n = pcall(function() return ship.Captives:GetArrayNum() end)
            if okC then used = used + n end
            max = tonumber(prop(ship, "Max Captive", 0)) or 0
            if max <= 0 then return end -- unknown slot count: better to leave the pods alone
            if used >= max then
                if not lastFull then log("captive slots full (" .. used .. "/" .. max .. "): allies leave the pods alone") end
                lastFull = true
                return
            end
            lastFull = false
        end

        local pl = loc(ship)
        if not pl then return end
        local allies = FindAllOf(ALLY_SHIP)
        if not allies then return end
        local live = {}
        for _, a in ipairs(allies) do
            if alive(a) and prop(a, "AITypes", -1) == AI_ALLY and prop(a, "Dead?", false) ~= true then
                local l = loc(a)
                if l then live[#live + 1] = { actor = a, loc = l } end
            end
        end
        if #live == 0 then
            if not lastNote.none or now - lastNote.none >= 4 then
                lastNote.none = now
                log("pods past their grace window, but no living allied ship found")
            end
            return
        end

        for _, f in ipairs(free) do
            local pod = f.actor
            if not faction and used >= max then break end
            local pp = loc(pod)
            if pp then
                local best, bestD = nil, math.huge
                for _, a in ipairs(live) do
                    local d = dist2(a.loc, pp)
                    if d < bestD then best, bestD = a, d end
                end
                local reach = faction and fRange2 or range2
                if best and bestD <= reach and bestD < dist2(pl, pp) then
                    local short = (f.name:gsub("^.*%.", ""))
                    if faction then
                        local b = gameBuilder()
                        local okP = false
                        if b then okP = pcall(function() b[ADD_POWER](b, fPower, {}, {}) end) end
                        if okP then
                            pcall(function() pod:K2_DestroyActor() end)
                            done[f.name] = os.clock()
                            firstSeen[f.name] = nil
                            credited = credited + 1
                            log(string.format("ally ship picked up a pod %.0f m away: +%d Faction Power (%d so far) %s",
                                math.sqrt(bestD) / 100, fPower, credited, short))
                        elseif not warnedPower then
                            warnedPower = true
                            warn("pod pickup: Faction Power could not be added (" .. (b and "call failed" or "no Game_Builder") .. "), pods left alone")
                        end
                    else
                        local ok, err = pcall(function() pod:CatchByMother(best.actor) end)
                        if ok then
                            done[f.name] = os.clock()
                            firstSeen[f.name] = nil
                            caught = caught + 1
                            used = used + 1
                            recent[#recent + 1] = now
                            log(string.format("ally ship caught a pod %.1f km away (%d so far, slots %d/%d) %s",
                                math.sqrt(bestD) / 100000, caught, used, max, short))
                        else
                            warn("pod catch: " .. tostring(err))
                        end
                    end
                elseif best then
                    -- why a pod past its grace window is still waiting (Debug log, at most every 4 s per pod)
                    local nt = lastNote[f.name]
                    if not nt or now - nt >= 4 then
                        lastNote[f.name] = now
                        log(string.format("pod %s waits: nearest ally %.0f m, you %.0f m, reach %.0f m", (f.name:gsub("^.*%.", "")),
                            math.sqrt(bestD) / 100, math.sqrt(dist2(pl, pp)) / 100, math.sqrt(reach) / 100))
                    end
                end
            end
        end
    end

    local interval = math.max(1, cfg.Interval or 2.5)
    -- first run 1.25 s late: with the 2.5 s period against the 3 s ship scan the two never fall in the same frame
    GT.every(interval, function()
        local ok, err = pcall(tick)
        if not ok then warn("pod catch tick: " .. tostring(err)) end
    end, 1.25)
    if cfg.Credit == "faction" then
        log(string.format("pod catchers on (faction credit): ally within %d m picks a pod up after %.0f s, +%d Faction Power, every %.1f s",
            cfg.FactionRange or 1000, tonumber(cfg.GraceSeconds) or 8, cfg.FactionPowerPerPilot or 50, interval))
    else
        log(string.format("pod catchers on: range %d m, grace %.0f s, every %.1f s", cfg.Range, tonumber(cfg.GraceSeconds) or 8, interval))
    end
end

return P
