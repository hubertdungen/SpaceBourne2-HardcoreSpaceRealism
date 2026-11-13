--[[
  Hardcore Space Realism for SpaceBourne 2 (UE4SS Lua mod)
  Part of the SpaceBourne 2 realism set: the space counterpart of Hardcore Tactical Realism.
  0.1.0: the ally pod catchers (podcatch.lua, moved here from Bigger Armies 0.2.0, tested there) and the enemy
  doctrine by tier (doctrine.lua, OFF by default until it has been tested in game).
  0.2.0: smarter allied ships (allies.lua: retreat when badly damaged, shared target), OFF by default until tested.
  shiputil.lua is the read-only helper set for the ship modules. DESIGN.md has the research and the plan.
  Timed work runs on the shared gametick.lua (no LoopAsync / ExecuteWithDelay / ExecuteAsync, see its header).
]]

local VERSION = "0.2.0"

-- Folder and log ---------------------------------------------------------------------------------------
local DIR
do
    local src = debug.getinfo(1, "S").source:gsub("^@", "")
    local cut
    for i in src:lower():gmatch("()[\\/]scripts[\\/]") do cut = i end
    DIR = cut and src:sub(1, cut - 1) or (".\\Mods\\HardcoreSpaceRealism")
end
local MODS = DIR:gsub("[\\/][^\\/]*$", "") -- the Mods folder (parent of this mod's folder)
local LOG = DIR .. "\\hardcorespacerealism.log"
local verbose = false

local function write(prefix, ...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    local f = io.open(LOG, "a")
    if f then f:write(os.date("%H:%M:%S "), prefix, table.concat(t, " "), "\n"); f:close() end
    return table.concat(t, " ")
end
local function log(...) if verbose then write("", ...) end end
local function warn(...) print("[HardcoreSpaceRealism] " .. write("WARN ", ...) .. "\n") end

-- Settings ---------------------------------------------------------------------------------------------
local defaults = { Enabled = true, Debug = false }
local okCfg, cfg = pcall(require, "config")
if not okCfg or type(cfg) ~= "table" then
    warn("config.lua could not be read (" .. tostring(cfg) .. "); using defaults")
    cfg = {}
end
for k, v in pairs(defaults) do if cfg[k] == nil or type(cfg[k]) ~= type(v) then cfg[k] = v end end
if cfg.Debug then verbose = true end

local podCfg = type(cfg.PodCatchers) == "table" and cfg.PodCatchers or {}
if podCfg.Enabled == nil then podCfg.Enabled = true end
if type(podCfg.Range) ~= "number" then podCfg.Range = 5000 end
podCfg.Range = math.max(100, math.min(50000, podCfg.Range))
if type(podCfg.Interval) ~= "number" then podCfg.Interval = 2.5 end

if not cfg.Enabled then
    warn("Hardcore Space Realism " .. VERSION .. " loaded, switched off in config.lua")
    return
end

-- Bigger Armies 0.2.0 has its own pod catchers (the same code). Leave the pods to it while it is on. -------
-- Detection: its scripts\podcatch.lua exists (0.2.1 and later do not have it), it is enabled (mods.txt line
-- "BiggerArmies : 1", or no line and an enabled.txt), and its config.lua does not switch the pod catchers off.
local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

local function baHasPodCatchers()
    local ba = MODS .. "\\BiggerArmies"
    if not readFile(ba .. "\\scripts\\podcatch.lua") then return false end
    local on
    local list = readFile(MODS .. "\\mods.txt")
    if list then
        for line in list:gmatch("[^\r\n]+") do
            local name, v = line:match("^%s*([%w_%-]+)%s*:%s*(%d)")
            if name == "BiggerArmies" then on = (v == "1") end
        end
    end
    if on == nil then on = readFile(ba .. "\\enabled.txt") ~= nil end
    if not on then return false end
    local chunk = loadfile(ba .. "\\scripts\\config.lua")
    if chunk then
        local ok, c = pcall(chunk)
        if ok and type(c) == "table" then
            if c.Enabled == false then return false end
            if type(c.PodCatchers) == "table" and c.PodCatchers.Enabled == false then return false end
        end
    end
    return true
end

-- Timers -----------------------------------------------------------------------------------------------
local GT = require("gametick")
GT.log = function(msg) warn(msg) end
GT.drive(GT.HUD_TICK, "hud")
GT.drive(GT.FOOT_TICK, "foot")
GT.boot()

local podsOn = "off"
if podCfg.Enabled then
    if baHasPodCatchers() then
        podsOn = "left to Bigger Armies"
        write("", "Bigger Armies 0.2.0 is on with its pod catchers: this mod leaves the pods to it (update Bigger Armies to 0.2.1 or switch its PodCatchers off to use these)")
    else
        local okP, P = pcall(require, "podcatch")
        if okP then
            local okS, err = pcall(P.start, GT, podCfg, log, warn)
            if okS then podsOn = "on" else warn("podcatch.lua: " .. tostring(err)) end
        else
            warn("podcatch.lua: " .. tostring(P))
        end
    end
end

local docCfg = type(cfg.EnemyDoctrine) == "table" and cfg.EnemyDoctrine or {}
if docCfg.Enabled == nil then docCfg.Enabled = false end
local docOn = "off"
if docCfg.Enabled then
    local okD, D = pcall(require, "doctrine")
    if okD then
        local okS, err = pcall(D.start, GT, docCfg, log, warn)
        if okS then docOn = "on" else warn("doctrine.lua: " .. tostring(err)) end
    else
        warn("doctrine.lua: " .. tostring(D))
    end
end

local allyCfg = type(cfg.AlliedShips) == "table" and cfg.AlliedShips or {}
if allyCfg.Enabled == nil then allyCfg.Enabled = false end
local allyOn = "off"
if allyCfg.Enabled then
    local okA, A = pcall(require, "allies")
    if okA then
        local okS, err = pcall(A.start, GT, allyCfg, log, warn)
        if okS then allyOn = "on" else warn("allies.lua: " .. tostring(err)) end
    else
        warn("allies.lua: " .. tostring(A))
    end
end

warn("Hardcore Space Realism " .. VERSION .. " loaded: ally pod catchers " .. podsOn .. ", enemy doctrine " .. docOn
    .. ", allied ships " .. allyOn)
