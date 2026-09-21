-- SRankAlert 0.5.3 -- observational alerts with deliberate host restart control.
local source, Diff, Toast, Queue = require("source"), require("diff"), require("toast"), require("queue")
local Presentation = require("presentation")
local input = require("controls").new()
local HUD = "/Game/Blueprints/Widgets/HUD/W_HumanCharacter_HUD_V2.W_HumanCharacter_HUD_V2_C"
local HUD_SHORT = "W_HumanCharacter_HUD_V2_C"
local function log(message) print("[SRankAlert] " .. tostring(message) .. "\n") end
-- Load user settings before scheduling work; defaults live in the config module.
local CONFIG = require("sra_config").load(log)
local function try(fn) local ok, v = pcall(fn); if ok then return v end end
local function valid(o) return o and try(function() return o:IsValid() end) == true end
local function name(o)
    if not valid(o) then return nil end
    local address = try(function() return o:GetAddress() end)
    if address ~= nil then return tostring(address) end
end
local function live(o)
    if not valid(o) then return false end
    local n = try(function() return o:GetFName():ToString() end)
    return type(n) == "string" and not n:find("Default__", 1, true)
end
local tier = type(ExecuteInGameThreadWithDelay) == "function" and "delayed"
    or (type(ExecuteWithDelay) == "function" and type(ExecuteInGameThread) == "function" and "composed") or "none"
local latched = {}
local function once(key, message)
    if latched[key] then return end
    latched[key] = true
    log(message)
end
local function schedule(ms, fn)
    local function guarded()
        -- If available, an explicit false is grounds to refuse engine access.
        if type(IsInGameThread) == "function" and try(IsInGameThread) ~= true then
            once("thread", "game-thread assertion failed; callback dropped")
            return
        end
        local ok, err = pcall(fn)
        if not ok then once("callback:" .. tostring(err), "callback failed: " .. tostring(err)) end
    end
    local ok = false
    if tier == "delayed" then ok = pcall(ExecuteInGameThreadWithDelay, ms, guarded)
    elseif tier == "composed" then
        ok = pcall(ExecuteWithDelay, ms, function()
            -- This background callback must never dereference a UObject.
            if not pcall(ExecuteInGameThread, guarded) then
                once("marshal", "ExecuteInGameThread rejected work; monitoring stopped")
            end
        end)
    end
    if not ok then once("schedule", "no usable game-thread scheduler; monitoring stopped") end
    return ok
end

source.configure(log, CONFIG.DIAGNOSTICS)
local enabled, active, pending = CONFIG.START_ENABLED, nil, nil
local toggleArmed = false -- require a release before the first press on each HUD
local attachGeneration, pollGeneration = 0, 0
local diff, queue = Diff.new(CONFIG.TRIGGERS), Queue.new()
local issueSignature, coverage = nil, nil
local missionWorld
local showNext
local function display(message, refresh)
    message.visual.persistent = message.sound == true or message.visual.fontProbe == true
    message.visual.restartAvailable = false
    local pc = active.controller
    if message.sound and CONFIG.RESTART_ENABLED and valid(pc)
        and try(function() return pc:IsLocalController() end)==true
        and try(function() return pc:HasAuthority() end)==true then
        message.visual.restartAvailable = true
    end
    active:show(message.visual, refresh)
    if message.sound and not refresh then active:playSound() end
    if message.visual.persistent then return end
    local generation, owner = queue.generation, active
    schedule(CONFIG.ALERT_MS, function()
        if generation ~= queue.generation or owner ~= active then return end
        if owner:isValid() then owner:hide() end
        if queue:finish(generation) then showNext() end
    end)
end
showNext = function()
    if not enabled or not active or not active:isValid() then return end
    local message = queue:next()
    if message then display(message) end
end
local function enqueue(visual, sound)
    if not enabled then return end
    if sound and queue.current and queue.current.sound then
        local current = queue.current
        current.visual = Presentation.merge(current.visual, visual)
        queue.pending = {}
        display(current, true)
        return
    end
    if sound then
        -- Health/startup notices must not delay violations, including ones
        -- already waiting behind another event.
        local keep = {}
        for _, message in ipairs(queue.pending) do
            if message.sound then keep[#keep + 1] = message end
        end
        queue.pending = keep
        if queue.current and not queue.current.sound then
            queue.generation = queue.generation + 1
            queue.current = nil
            if active and active:isValid() then active:hide() end
        end
    end
    queue:push({ visual = visual, sound = sound })
    showNext()
end
local function clear()
    queue:clear()
    if active and active:isValid() then active:hide() end
end
local function dismissCurrent()
    if not queue.current then return end
    -- Invalidate the outgoing dismiss timer, but retain the FIFO backlog and
    -- every detection high-water mark. Future alerts remain enabled.
    queue.generation = queue.generation + 1
    queue.current = nil
    if active and active:isValid() then active:hide() end
    showNext()
end
local function pollOnce()
    local s = source.read()
    if diff.epoch ~= nil and s.epoch ~= diff.epoch then clear(); issueSignature = nil end
    local events, issues = diff:update(s)
    local details = {}
    for _, issue in ipairs(s.issues or {}) do details[#details + 1] = issue end
    for key, issue in pairs(issues) do
        if issue ~= "unreadable" then details[#details + 1] = key .. ": " .. issue end
    end
    table.sort(details)
    local signature = table.concat(details, " | ")
    coverage = signature
    if signature ~= issueSignature then
        issueSignature = signature
        if signature ~= "" then
            log("coverage UNKNOWN: " .. signature)
            enqueue(Presentation.notice("S-RANK CHECK INCOMPLETE", "Some mission data is unavailable", "warning"), false)
        else
            log("configured core data readable; monitoring active (no final-rank guarantee)")
            enqueue(Presentation.notice("S-RANK ALERTS ACTIVE", "Watching for new incidents"), false)
        end
    end
    -- Suppress on explicit unofficial scoring OR unreadable scoring policy.
    -- Keep diffing while muted so enabling cannot replay old events.
    if s.official ~= true then
        -- Player death is useful in its own right, independent of the rank
        -- rules. Still notify, without making a vanilla S-rank assertion.
        local deaths = {}
        for _, event in ipairs(events) do
            if event.category == "PLAYER_DIED" then deaths[#deaths + 1] = event end
        end
        events = deaths
    end
    if #events > 0 then
        for _, event in ipairs(events) do
            log("event " .. event.id .. ": " .. event.label .. ", delta=" .. event.count ..
                (event.initial and " (initial observation)" or ""))
        end
        -- Preserve four-event grouping; presentation backlog is bounded separately.
        for first = 1, #events, 4 do
            local group = {}
            for i = first, math.min(first + 3, #events) do group[#group + 1] = events[i] end
            enqueue(Presentation.events(group), true)
        end
    end
end
local function tick(generation)
    if generation ~= pollGeneration then return end
    if not active or not active:isValid() then
        if active then pcall(function() active:destroy() end) end
        active = nil; queue:clear(); return
    end
    active:ensureViewport()
    local ok, err = pcall(pollOnce)
    if not ok then
        once("poll", "poll failed; coverage UNKNOWN: " .. tostring(err))
        if coverage ~= "poll error" then
            coverage = "poll error"
            enqueue(Presentation.notice("S-RANK CHECK INCOMPLETE", "Mission data could not be read", "warning"), false)
        end
    end
    schedule(CONFIG.POLL_MS, function() tick(generation) end)
end
local function controlTick(generation)
    if generation ~= pollGeneration or not active or not active:isValid() then return end
    local pc = active.controller
    if CONFIG.TOGGLE_KEY ~= "" then
        local toggleDown
        if valid(pc) then
            toggleDown = try(function() return pc:IsInputKeyDown({KeyName=FName(CONFIG.TOGGLE_KEY)}) end)
        end
        if toggleDown == false then toggleArmed = true
        elseif toggleDown ~= true then toggleArmed = false
        elseif toggleArmed then
            toggleArmed = false
            if not enabled then
                -- Catch changes since the last poll while still muted. Otherwise an
                -- incident immediately before re-enabling could appear as a new one.
                local ok, err = pcall(pollOnce)
                if not ok then
                    log("alerts remain off: could not refresh mission data: " .. tostring(err))
                    schedule(50,function() controlTick(generation) end)
                    return
                end
            end
            enabled = not enabled
            clear()
            input = require("controls").new() -- discard any partially held restart
            log("alerts " .. (enabled and "ON" or "OFF") .. " via " .. CONFIG.TOGGLE_KEY)
            local incomplete = enabled and coverage ~= ""
            local message = {sound=false, visual=Presentation.notice(
                enabled and "S-RANK ALERTS ON" or "S-RANK ALERTS OFF",
                enabled and (incomplete and "Some mission data is unavailable" or "Watching for new incidents")
                    or ("Press " .. CONFIG.TOGGLE_KEY .. " to turn alerts back on"),
                incomplete and "warning" or "info")}
            -- One short confirmation is allowed while muted; incident enqueueing
            -- remains disabled and the shared queue still handles dismissal/timers.
            queue:push(message)
            display(queue:next())
        end
    end
    local down, seconds
    if valid(pc) then
        down=try(function() return pc:IsInputKeyDown({KeyName=FName(CONFIG.ACTION_KEY)}) end)
        seconds=try(function() return pc:GetInputKeyTimeDown({KeyName=FName(CONFIG.ACTION_KEY)}) end)
    end
    local message=queue.current
    local canRestart=CONFIG.RESTART_ENABLED and message and message.sound and valid(pc)
        and try(function() return pc:IsLocalController() end)==true
        and try(function() return pc:HasAuthority() end)==true
    local action=input:update(message,down,seconds,
        CONFIG.RESTART_HOLD_SECONDS,canRestart,
        CONFIG.DISMISS_TAP_SECONDS)
    local progress = canRestart and down == true and input.armed and input.pressed
        and not input.fired and type(seconds)=="number"
        and math.max(0, math.min(1, seconds / CONFIG.RESTART_HOLD_SECONDS)) or nil
    active:setHoldProgress(progress)
    if action=="dismiss" then dismissCurrent()
    elseif action=="restart" then
        local world=active.world
        local mode=valid(world) and try(function() return world.AuthorityGameMode end)
        if valid(mode) and try(function() return mode:HasAuthority() end)==true then
            clear()
            log("deliberate " .. CONFIG.ACTION_KEY .. " hold: host restart requested")
            local ok,err=pcall(function() mode:RestartGame() end)
            if not ok then log("restart failed: " .. tostring(err)) end
        else log("restart unavailable: authoritative game mode missing") end
    end
    schedule(50,function() controlTick(generation) end)
end
local function attach(hud)
    if not live(hud) then return end
    local nextWorld = try(function() return hud:GetWorld() end)
    -- A replacement character HUD in the same mission must not clear a death
    -- alert or interrupt its hold. The independent overlay already owns both.
    if active and active:isValid() and name(active.world) == name(nextWorld) then return end
    if active and active:isValid() and name(active.hud) == name(hud) then return end
    if pending and live(pending) and name(pending) == name(hud) then return end
    log("character HUD observed; waiting for widget tree")
    if CONFIG.VERBOSE then log("attach target: " .. name(hud)) end
    attachGeneration, pollGeneration = attachGeneration + 1, pollGeneration + 1
    clear()
    if active then pcall(function() active:destroy() end) end
    active, pending = nil, hud
    toggleArmed = false
    if not valid(missionWorld) or not valid(nextWorld) or name(missionWorld) ~= name(nextWorld) then
        source.reset(hud)
        diff = Diff.new(CONFIG.TRIGGERS)
        issueSignature, coverage = nil, nil
        missionWorld = nextWorld
    end
    local generation, elapsed = attachGeneration, 0
    local function attempt()
        if generation ~= attachGeneration then return end
        if not live(hud) then pending = nil; log("HUD became invalid; attach cancelled"); return end
        local handle, reason = Toast.attach(hud, CONFIG, log, schedule)
        if handle then
            active, pending = handle, nil
            log("toast attached after " .. elapsed .. "ms; poll=" .. CONFIG.POLL_MS .. "ms")
            tick(pollGeneration)
            controlTick(pollGeneration)
            if CONFIG.FONT_PROBE then
                local specimen = Presentation.notice("FONT TEST - SCREENSHOT", "")
                specimen.fontProbe = true
                enqueue(specimen, false)
            end
        elseif elapsed >= 15000 then
            pending = nil
            log("attach abandoned after 15000ms: " .. tostring(reason))
        else
            elapsed = elapsed + 250
            schedule(250, attempt)
        end
    end
    attempt()
end

log("loaded v0.5.3; " .. _VERSION .. "; " .. CONFIG.ACTION_KEY .. " tap dismiss / " ..
    (CONFIG.RESTART_ENABLED and "hold host restart enabled (experimental)" or "restart disabled"))
log(CONFIG.TOGGLE_KEY ~= "" and (CONFIG.TOGGLE_KEY .. " toggles alerts in missions; starting " .. (enabled and "ON" or "OFF"))
    or ("alert toggle shortcut disabled; starting " .. (enabled and "ON" or "OFF")))
log("game-thread route: " .. (tier == "delayed" and "ExecuteInGameThreadWithDelay" or
    tier == "composed" and "ExecuteWithDelay + ExecuteInGameThread" or "NONE (disabled)"))
log("S-rank inference uses vanilla rules; no verified group pass/fail or final S-eligibility flag")
if tier == "none" then return end
local notified, notifyError = pcall(NotifyOnNewObject, HUD, function(hud)
    schedule(0, function() attach(hud) end)
end)
if not notified then log("NotifyOnNewObject registration failed: " .. tostring(notifyError)) end
-- Load-time lookup supports an already-created HUD. No UObject access at
-- script load or in the notification callback itself.
schedule(0, function()
    local all = try(function() return FindAllOf(HUD_SHORT) end)
    if all then for _, hud in ipairs(all) do if live(hud) then attach(hud); return end end end
    local hud = try(function() return FindFirstOf(HUD_SHORT) end)
    if live(hud) then attach(hud) else log("waiting for a mission character HUD") end
end)
