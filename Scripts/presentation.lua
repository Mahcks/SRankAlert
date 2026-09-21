-- Presentation only: consumes existing diff events, never changes detection.
local M = {}
local TITLES = {
    CIVILIAN_KILLED = "CIVILIAN KILLED", SUSPECT_KILLED = "SUSPECT KILLED",
    PLAYER_DIED = "PLAYER KILLED", PENALTIES = "PENALTY RECORDED",
    OBJECTIVE_FAILED = "OBJECTIVE FAILED", CIVILIAN_INJURED = "CIVILIAN INJURED",
    REQUIRED_BONUS_LOST = "BONUS UNAVAILABLE",
}
local function clean(s, limit)
    s = tostring(s or ""):gsub("[%c]", " ")
    local length = utf8.len(s)
    if length and length > limit then s = s:sub(1, utf8.offset(s, limit + 1) - 1) .. "..." end
    return s
end
function M.notice(headline, context, severity)
    return { headline = clean(headline, 40), context = clean(context, 110), severity = severity or "info" }
end
local function single(primary)
    local context = {}
    if primary.category == "PLAYER_DIED" then
        context[#context + 1] = primary.label:gsub("^Player died: ", "")
    elseif primary.category == "OBJECTIVE_FAILED" then
        context[#context + 1] = primary.label:gsub("^Objective failed: ", "")
    elseif primary.category == "REQUIRED_BONUS_LOST" then
        context[#context + 1] = primary.label:gsub("^Required bonus disabled: ", "")
            :gsub(" %(S%-rank impact unverified%)$", "")
    end
    if primary.count > 1 then context[#context + 1] = "Count: " .. primary.count end
    if primary.initial then context[#context + 1] = "Already recorded; timing unknown" end
    if primary.warning then context[#context + 1] = "S-rank impact unconfirmed" end
    local title = TITLES[primary.category] or "S-RANK ALERT"
    if primary.category == "PENALTIES" then
        title = primary.label:gsub("^Penalty: ", "")
        if title == "" then title = "PENALTY RECORDED" end
    end
    local result = M.notice(title, "", primary.warning and "warning" or "critical")
    result.context = clean(table.concat(context, " / "), 110)
    return result
end

-- Keep one counter per detection category, not one counter per poll/batch. A
-- kill and a penalty can describe the same action, so never sum them into a
-- purported total number of distinct incidents.
local ORDER = {"CIVILIAN_KILLED", "SUSPECT_KILLED", "PLAYER_DIED", "PENALTIES",
    "OBJECTIVE_FAILED", "CIVILIAN_INJURED", "REQUIRED_BONUS_LOST"}
local LABELS = {
    CIVILIAN_KILLED={"civilian killed", "civilians killed"},
    SUSPECT_KILLED={"suspect killed", "suspects killed"},
    PLAYER_DIED={"player death", "player deaths"},
    PENALTIES={"penalty", "penalties"},
    OBJECTIVE_FAILED={"objective failed", "objectives failed"},
    CIVILIAN_INJURED={"injury warning", "injury warnings"},
    REQUIRED_BONUS_LOST={"bonus warning", "bonus warnings"},
}
local function add(summary, event)
    local previous = summary[event.category]
    if not previous then
        summary[event.category] = {category=event.category, label=event.label,
            warning=event.warning, count=event.count, initial=event.initial,
            mixedLabels=event.mixedLabels}
    else
        previous.count = previous.count + event.count
        previous.initial = previous.initial or event.initial
        previous.warning = previous.warning and event.warning
        previous.mixedLabels = previous.mixedLabels or event.mixedLabels or previous.label ~= event.label
    end
end
local function render(summary)
    local ordered = {}
    -- Put confirmed incidents before optional warnings, then use stable category
    -- order so batching and iteration order cannot change the displayed result.
    for _, warning in ipairs({false, true}) do
        for _, category in ipairs(ORDER) do
            local event = summary[category]
            if event and (event.warning == true) == warning then ordered[#ordered+1] = event end
        end
    end
    local result
    if #ordered == 1 then
        local event = ordered[1]
        if event.mixedLabels then
            local label = event.category == "PLAYER_DIED" and "Player died: Multiple players"
                or event.category == "OBJECTIVE_FAILED" and "Objective failed: Multiple objectives"
                or event.category == "REQUIRED_BONUS_LOST" and "Required bonus disabled: Multiple bonuses"
                or event.category == "PENALTIES" and "Penalty: PENALTIES RECORDED" or event.label
            event = {category=event.category, label=label, count=event.count,
                warning=event.warning, initial=event.initial}
        end
        result = single(event)
    else
        local parts, initial = {}, false
        for _, event in ipairs(ordered) do
            local labels = LABELS[event.category]
            local part = tostring(event.count) .. " " .. labels[event.count == 1 and 1 or 2]
            if event.category == "PENALTIES" and not event.mixedLabels then
                part = part .. ": " .. clean(event.label:gsub("^Penalty: ", ""), 32)
            end
            parts[#parts+1] = part
            initial = initial or event.initial
        end
        local prefix = initial and "Already recorded; timing unknown / " or ""
        local context = prefix
        for i, part in ipairs(parts) do
            local candidate = context .. (i > 1 and " / " or "") .. part
            local remaining = #parts-i
            local suffix = remaining > 0 and (" / +" .. remaining .. " types") or ""
            if utf8.len(candidate .. suffix) > 110 then
                context = context .. " / +" .. (#parts-i+1) .. " types"
                break
            end
            context = candidate
        end
        result = M.notice("MULTIPLE INCIDENTS", context,
            ordered[1].warning and "warning" or "critical")
    end
    result.incidents = summary
    return result
end
function M.events(events)
    local summary = {}
    for _, event in ipairs(events) do add(summary, event) end
    return render(summary)
end
function M.merge(previous, incoming)
    local summary = {}
    for _, visual in ipairs({previous, incoming}) do
        for _, category in ipairs(ORDER) do
            local event = visual.incidents[category]
            if event then add(summary, event) end
        end
    end
    return render(summary)
end
return M
