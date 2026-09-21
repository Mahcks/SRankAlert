-- Read-only reflection adapter. Reference API/call conventions: Nokama's
-- MissionObjectiveCounter, MIT; see README.md for detection scope and limitations.
local M = {}
local log, verbose = function() end, false
local warned, shapes, resolved = {}, {}, {}
local manager, state, world, epoch = nil, nil, nil, 0
local lastManager, lastState

local function try(fn) local ok, v = pcall(fn); if ok then return v end end
local function field(o, k) return try(function() return o[k] end) end
local function number(v)
    local n = tonumber(v)
    if n and n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0 then return n end
end
local function count(v) local n = number(v); if n and n >= 0 then return n end end
local function boolean(v) if type(v) == "boolean" then return v end end
local function text(v) return try(function() return v:ToString() end) end
local function valid(o) return o and try(function() return o:IsValid() end) == true end
local function name(o)
    if not valid(o) then return nil end
    -- GetFullName walks Outer pointers; the reported native crash occurred
    -- in that traversal. Identity needs only a validated object address.
    local address = try(function() return o:GetAddress() end)
    if address ~= nil then return tostring(address) end
end
local function live(o)
    if not valid(o) then return false end
    local n = try(function() return o:GetFName():ToString() end)
    return type(n) == "string" and not n:find("Default__", 1, true)
end
local function health(key, ok, detail)
    if not ok and not warned[key] then
        warned[key] = true
        log("could not read " .. key .. ": " .. (detail or "missing or incompatible field") .. "; coverage UNKNOWN")
    elseif ok and warned[key] then
        warned[key] = nil
        log(key .. " recovered")
    end
end
local function shape(key, value)
    if not verbose then return end
    if shapes[key] ~= value then
        shapes[key] = value
        log(key .. " call shape resolved: " .. value)
    end
end
local function inWorld(o)
    return live(o) and name(try(function() return o:GetWorld() end)) == world
end
local function find(class)
    local all = try(function() return FindAllOf(class) end)
    if all then for _, o in ipairs(all) do if inWorld(o) then return o end end end
    local first = try(function() return FindFirstOf(class) end)
    if inWorld(first) then return first end
end
function M.configure(logger, diagnostics) log, verbose = logger, diagnostics end
function M.reset(hud)
    manager, state, lastManager, lastState = nil, nil, nil, nil
    world = name(try(function() return hud:GetWorld() end))
    warned, resolved = {}, {}
    epoch = epoch + 1
end

-- Fresh tables per invocation. Exact parameter names are searched across
-- every argument table because UE4SS can put all outputs in the first one.
local function out(obj, fn, names)
    local args, values, conventions = {}, {}, {}
    for i = 1, #names do args[i] = {} end
    local ok, returns = pcall(function() return table.pack(obj[fn](obj, table.unpack(args))) end)
    if ok then
        for i, key in ipairs(names) do
            local raw, route
            for _, t in ipairs(args) do
                if t[key] ~= nil then raw, route = t[key], "tables/by-name"; break end
            end
            if raw == nil and args[i].Value ~= nil then raw, route = args[i].Value, "tables/Value" end
            if raw == nil and args[i][1] ~= nil then raw, route = args[i][1], "tables/index" end
            if raw == nil and returns.n == #names then raw, route = returns[i], "positional returns" end
            values[key] = count(raw)
            if values[key] ~= nil then conventions[#conventions + 1] = key .. "=" .. route end
        end
    end
    if #conventions > 0 then shape(fn, table.concat(conventions, ", ")) end
    for _, key in ipairs(names) do health(fn .. "." .. key, values[key] ~= nil, ok and nil or tostring(returns)) end
    return values
end
local function unwrap(value, probe)
    local inner = try(function() return value:get() end)
    if inner and field(inner, probe) ~= nil then return inner, ":get()" end
    return value, "direct"
end
local function array(obj, fn)
    local result = try(function() return obj[fn](obj) end)
    local length = result and count(try(function() return #result end))
    health(fn, length ~= nil)
    if length ~= nil then shape(fn, "return TArray"); return result, length end
end
local function readPenalties(mgr)
    local a, n = array(mgr, "GetPenaltyScoreGroups")
    if not a then return nil, false end
    local result, complete = {}, true
    for i = 1, n do
        local p, route = unwrap(field(a, i), "GroupName")
        local label = text(field(p, "GroupName"))
        local total = count(field(p, "PenaltyCount"))
        local score = number(field(p, "Score"))
        if label and total and score then
            shape("FScorePenaltyData", route .. " GroupName/Score/PenaltyCount")
            -- Score sign is not assumed: different versions may store a
            -- deduction as either a magnitude or a signed negative number.
            if score ~= 0 then
                if result[label] then result[label].count = result[label].count + total
                else result[label] = { name = label, count = total } end
            end
        else complete = false end
    end
    health("GetPenaltyScoreGroups.FScorePenaltyData", complete)
    return result, complete
end
local function readGroups(mgr)
    local a, n = array(mgr, "GetScoreGroups")
    if not a then return nil end
    local bonuses, complete = {}, true
    for i = 1, n do
        local g, route = unwrap(field(a, i), "GroupName")
        local label = text(field(g, "GroupName"))
        local scores = field(g, "Scores")
        local size = scores and count(try(function() return #scores end))
        if not label or not size then complete = false else
            shape("FScoreGroup", route .. " GroupName/Scores")
            if verbose and not resolved[label] then
                resolved[label] = true
                log("score group " .. label .. ": " .. size .. " entries; no verified group S-rank verdict")
            end
            for j = 1, size do
                local s = unwrap(field(scores, j), "Bonuses")
                local component = field(s, "FromScoringComponent")
                local id = live(component) and name(component)
                local list = field(s, "Bonuses")
                local length = list and count(try(function() return #list end))
                if not id or not length then complete = false else
                    for k = 1, length do
                        local b = unwrap(field(list, k), "ScoreName")
                        local bn = text(field(b, "ScoreName"))
                        local enabled, given, required = boolean(field(b, "bEnabled")),
                            boolean(field(b, "bGiven")), boolean(field(b, "bRequired"))
                        if bn and enabled ~= nil and given ~= nil and required ~= nil then
                            -- Component identity is stable if a score moves
                            -- between groups; do not use a TArray index as ID.
                            bonuses[id .. "/" .. bn] = { name = bn, enabled = enabled,
                                given = given, required = required }
                        else complete = false end
                    end
                end
            end
        end
    end
    health("GetScoreGroups.FScoreData.Bonuses", complete)
    return bonuses
end
local function readObjectives(gs)
    local list = field(gs, "MissionObjectives")
    local length = list and count(try(function() return #list end))
    if not length then health("GameState.MissionObjectives", false); return nil end
    local result, complete = {}, true
    for i = 1, length do
        local obj = field(list, i)
        if not live(obj) then complete = false else
            local status = number(field(obj, "ObjectiveStatus"))
            local label = text(field(obj, "ObjectiveName"))
            if label and (status == 0 or status == 1 or status == 2) then
                result[name(obj)] = { name = label, status = status }
            else complete = false end
        end
    end
    health("GameState.MissionObjectives", complete)
    return result
end
local function readPlayers(gs)
    -- PlayerState.Deaths is replicated and survives pawn destruction. Never
    -- infer a death from a missing pawn, disconnect, spectating, or zero HP.
    local list = field(gs, "PlayerArray")
    local length = list and count(try(function() return #list end))
    if not length then health("GameState.PlayerArray", false); return nil, false end
    local result, complete = {}, true
    for i = 1, length do
        local player = field(list, i)
        if not inWorld(player) then complete = false else
            local bot = boolean(field(player, "bIsABot"))
            if bot == nil then complete = false
            elseif not bot then
                local deaths = count(field(player, "Deaths"))
                local id = name(player)
                health("ReadyOrNotPlayerState.Deaths " .. id, deaths ~= nil)
                if deaths == nil then complete = false else
                    local display = try(function() return player:GetPlayerName() end)
                    if type(display) ~= "string" then display = text(display) end
                    result[id] = { name = display or "Player", deaths = deaths }
                    shape("ReadyOrNotPlayerState.Deaths", "replicated int32 property (human PlayerArray entry)")
                end
            end
        end
    end
    health("GameState.PlayerArray", complete)
    return result, complete
end
function M.read()
    if not world then return { epoch = epoch, issues = { "HUD world unavailable" } } end
    if not inWorld(manager) then manager = find("ScoringManager") end
    if not inWorld(state) then state = find("ReadyOrNotGameState") end
    -- Actor replication churn alone does not prove a mission restart.
    -- Only the caller's confirmed world change resets high-water marks.
    local changed = false
    if manager then
        if lastManager and (not live(lastManager) or name(lastManager) ~= name(manager)) then changed = true end
        lastManager = manager
    end
    if state then
        if lastState and (not live(lastState) or name(lastState) ~= name(state)) then changed = true end
        lastState = state
    end
    if changed then log("mission actors changed in the same world; preserving event high-water marks") end
    health("ScoringManager", manager ~= nil)
    health("ReadyOrNotGameState", state ~= nil)
    local s = { epoch = epoch, issues = {} }
    if manager then
        -- bIsOfficialScoring is replicated in the SDK. Unknown remains nil.
        s.official = boolean(field(manager, "bIsOfficialScoring"))
        health("ScoringManager.bIsOfficialScoring", s.official ~= nil)
        local suspects = out(manager, "GetSuspectCount", { "OutReported", "OutArrested", "OutKilled", "OutTotal" })
        local civilians = out(manager, "GetCivilianCount", { "OutReported", "OutInjured", "OutKilled", "OutArrested", "OutTotal" })
        s.suspectKilled, s.civilianKilled, s.civilianInjured = suspects.OutKilled, civilians.OutKilled, civilians.OutInjured
        s.penalties, s.penaltiesComplete = readPenalties(manager)
        s.bonuses = readGroups(manager)
    end
    if state then
        s.objectives = readObjectives(state)
        s.players, s.playersComplete = readPlayers(state)
    end
    if s.suspectKilled == nil then s.issues[#s.issues + 1] = "suspect kills" end
    if s.civilianKilled == nil then s.issues[#s.issues + 1] = "civilian kills" end
    if not s.penaltiesComplete then s.issues[#s.issues + 1] = "penalties" end
    if not s.objectives or warned["GameState.MissionObjectives"] then s.issues[#s.issues + 1] = "objectives" end
    if not s.playersComplete then s.issues[#s.issues + 1] = "player deaths" end
    if s.official ~= true then s.issues[#s.issues + 1] = "official scoring unconfirmed; alerts suppressed" end
    return s
end
return M
