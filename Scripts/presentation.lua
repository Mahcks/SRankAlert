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
function M.events(events)
    local primary = events[1]
    -- A severe observation takes visual precedence, without adding events.
    for _, e in ipairs(events) do if not e.warning then primary = e; break end end
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
    local related = {}
    for _, e in ipairs(events) do
        if e ~= primary then related[#related+1] = e end
    end
    if related[1] then
        context[#context+1] = clean(related[1].label, 42)
    end
    local suffix = #related > 1 and (" / +" .. (#related-1) .. " more") or ""
    local title = TITLES[primary.category] or "S-RANK ALERT"
    if primary.category == "PENALTIES" then
        title = primary.label:gsub("^Penalty: ", "")
        if title == "" then title = "PENALTY RECORDED" end
    end
    local result = M.notice(title, "", primary.warning and "warning" or "critical")
    result.context = clean(table.concat(context, " / "), 105-#suffix) .. suffix
    return result
end
return M
