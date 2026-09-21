-- Pure Lua. No engine access. High-water marks survive unreadable snapshots,
-- counter rollback, array reordering, and presentation toggles.
local M = {}
function M.new(config)
    local self = { config = config, high = {}, objectives = {}, epoch = nil,
        penaltyBaseline = false, bonusState = {}, bonusFired = {} }

    function self:update(s)
        local events, issues = {}, {}
        if s.epoch ~= nil and s.epoch ~= self.epoch then
            self.high, self.objectives = {}, {}
            self.bonusState, self.bonusFired = {}, {}
            self.penaltyBaseline = false
            self.epoch = s.epoch
        end
        local function emit(category, key, label, delta, initial, warning)
            if not self.config[category] then return end
            events[#events + 1] = { id = key, category = category, label = label,
                count = delta, initial = initial, warning = warning == true }
        end
        local function counter(category, key, label, value, freshZero, warning)
            if value == nil then issues[key] = "unreadable"; return end
            local previous = self.high[key]
            if previous == nil and freshZero then previous = 0 end
            if previous == nil then
                self.high[key] = value
                if value > 0 then emit(category, key .. ":" .. value, label, value, true, warning) end
            elseif value < previous then
                -- Do not rearm at the lower value: a replication rollback is
                -- not proof that a new mission began.
                issues[key] = "counter decreased; waiting for high-water mark"
            elseif value > previous then
                self.high[key] = value
                emit(category, key .. ":" .. value, label, value - previous, false, warning)
            end
        end
        counter("CIVILIAN_KILLED", "civilianKilled", "Civilian killed", s.civilianKilled)
        counter("SUSPECT_KILLED", "suspectKilled", "Suspect killed (vanilla arrest score lost)", s.suspectKilled)
        if s.players then
            local keys = {}
            for key in pairs(s.players) do keys[#keys + 1] = key end
            table.sort(keys)
            for _, key in ipairs(keys) do
                local player = s.players[key]
                counter("PLAYER_DIED", "player:" .. key, "Player died: " .. player.name, player.deaths)
            end
        elseif self.config.PLAYER_DIED then issues.players = "unreadable" end
        if self.config.CIVILIAN_INJURED then
            counter("CIVILIAN_INJURED", "civilianInjured", "Civilian injured: S-rank impact unverified",
                s.civilianInjured, false, true)
        end
        if s.penalties ~= nil then
            local keys = {}
            for key in pairs(s.penalties) do keys[#keys + 1] = key end
            table.sort(keys)
            for _, key in ipairs(keys) do
                local p = s.penalties[key]
                counter("PENALTIES", "penalty:" .. key, "Penalty: " .. p.name,
                    p.count, self.penaltyBaseline)
            end
            -- Only a completely read array proves a previously absent group
            -- was zero. Partial arrays cannot establish a baseline.
            if s.penaltiesComplete then self.penaltyBaseline = true end
        else issues.penalties = "unreadable" end
        if s.objectives ~= nil then
            for key, o in pairs(s.objectives) do
                local previous = self.objectives[key]
                if o.status == 2 and previous ~= 2 then
                    emit("OBJECTIVE_FAILED", "objective:" .. key, "Objective failed: " .. o.name,
                        1, previous == nil)
                    self.objectives[key] = 2 -- sticky even if replication rolls back
                elseif previous ~= 2 then self.objectives[key] = o.status end
            end
        else issues.objectives = "unreadable" end
        if self.config.REQUIRED_BONUS_LOST and s.bonuses then
            for key, b in pairs(s.bonuses) do
                local previous = self.bonusState[key]
                if previous and previous.enabled and not previous.given and
                    b.required and not b.enabled and not b.given and not self.bonusFired[key] then
                    emit("REQUIRED_BONUS_LOST", "bonus:" .. key,
                        "Required bonus disabled: " .. b.name .. " (S-rank impact unverified)", 1, false, true)
                    self.bonusFired[key] = true
                end
                self.bonusState[key] = b
            end
        end
        return events, issues
    end
    return self
end
return M
