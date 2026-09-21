-- Persistent, validated settings. Existing user files are never rewritten.
local json = require("sra_dkjson")
local M = {}

local DEFAULTS = {
    ACTION_KEY = "F9",         -- Unreal key name; tap dismiss, hold restart
    TOGGLE_KEY = "F8",         -- toggle alerts in a mission; empty disables this shortcut
    RESTART_ENABLED = false,    -- experimental, host only; requires an explicit opt-in
    RESTART_HOLD_SECONDS = 3,
    DISMISS_TAP_SECONDS = 0.3, -- longer releases cancel hold, keeping alert visible
    SHOW_HOLD_PROGRESS = true,
    KEY_TILE_SIZE = 40,
    KEY_GLYPH_SIZE = 16,
    KEY_LABEL_SIZE = 13,
    KEY_GROUP_WIDTH = 170,
    KEY_OUTLINE_OPACITY = 1.0,
    KEY_FILL_OPACITY = 1.0,
    KEY_FILL_SATURATION = 0.95,
    KEY_FILL_BRIGHTNESS = 1.0,
    KEY_EMPTY_COLOR = "080808",
    DIVIDER_WIDTH = 64,
    DIVIDER_TOP_GAP = 10,
    DIVIDER_BOTTOM_GAP = 6,
    DIVIDER_OPACITY = 0.3,
    START_ENABLED = true,
    POLL_MS = 350,              -- invalid settings fall back to these defaults
    ALERT_MS = 5500,            -- unchanged total lifetime, including both fades
    SCALE = 1.0,
    WIDTH = 420,
    ANCHOR = "AboveCrosshair",  -- corners | TopCenter | Center | AboveCrosshair
    CENTER_OFFSET = 140,        -- Slate units above crosshair for AboveCrosshair
    MARGIN = 24,
    HEADLINE_SIZE = 18,
    CONTEXT_SIZE = 13,
    CONTROL_SIZE = 18,
    FONT_HEADLINE_FACE = "Bold",
    SMALL_FONT_PATH = "/Engine/EngineFonts/Roboto.Roboto",
    SMALL_FONT_FACE = "Regular",
    SMALL_FONT_TRACKING = 25,
    FONT_PROBE = false, -- optional alphabet test; Roboto verified by user
    INHERIT_HUD_FONT = true,
    FADE_IN_MS = 180,
    FADE_OUT_MS = 300,
    ANIMATION_STEP_MS = 30,     -- only while fading; no per-frame poll
    CONTEXT_GAP = 3,
    TEXT_OUTLINE_SIZE = 2,
    TEXT_OUTLINE_COLOR = "000000",
    SHADOW_OPACITY = 1.0,
    SHADOW_OFFSET = 2,
    HEADLINE_COLOR = "E6E9E7",
    CONTEXT_COLOR = "C1C6C5",
    CRITICAL_COLOR = "C58A80",
    WARNING_COLOR = "C7AE78",
    INFO_COLOR = "E6E9E7",
    SOUND = false,
    SOUND_PATH = "",           -- optional loaded USoundBase object path
    VERBOSE = false,
    DIAGNOSTICS = false,
    TRIGGERS = {
        CIVILIAN_KILLED = true,
        SUSPECT_KILLED = true,
        PLAYER_DIED = true,     -- replicated human PlayerState.Deaths increases
        PENALTIES = true,       -- actual PenaltyCount, no English-name filtering
        OBJECTIVE_FAILED = true,
        CIVILIAN_INJURED = false,    -- unverified S impact; warning only
        REQUIRED_BONUS_LOST = false, -- unverified S impact; warning only
    },
}

-- Ranges are deliberately bounded before values reach UMG or the scheduler.
-- A third value marks settings that require whole numbers (font sizes and milliseconds).
local RANGES = {
    RESTART_HOLD_SECONDS={1,5}, DISMISS_TAP_SECONDS={0.1,0.5},
    KEY_TILE_SIZE={16,96}, KEY_GLYPH_SIZE={8,32,true}, KEY_LABEL_SIZE={8,24,true},
    KEY_GROUP_WIDTH={60,400}, KEY_OUTLINE_OPACITY={0,1}, KEY_FILL_OPACITY={0,1},
    KEY_FILL_SATURATION={0,1}, KEY_FILL_BRIGHTNESS={0,1},
    DIVIDER_WIDTH={0,600}, DIVIDER_TOP_GAP={0,100}, DIVIDER_BOTTOM_GAP={0,100},
    DIVIDER_OPACITY={0,1}, POLL_MS={100,5000,true}, ALERT_MS={1000,30000,true},
    SCALE={0.5,3}, WIDTH={200,600}, CENTER_OFFSET={0,500}, MARGIN={0,500},
    HEADLINE_SIZE={10,24,true}, CONTEXT_SIZE={9,20,true}, CONTROL_SIZE={10,24,true},
    SMALL_FONT_TRACKING={-100,200,true}, FADE_IN_MS={0,10000,true},
    FADE_OUT_MS={0,10000,true}, ANIMATION_STEP_MS={16,100,true}, CONTEXT_GAP={0,12},
    TEXT_OUTLINE_SIZE={0,4,true}, SHADOW_OPACITY={0,1}, SHADOW_OFFSET={0,3},
}
local COLORS = {KEY_EMPTY_COLOR=true, TEXT_OUTLINE_COLOR=true, HEADLINE_COLOR=true,
    CONTEXT_COLOR=true, CRITICAL_COLOR=true, WARNING_COLOR=true, INFO_COLOR=true}
local ANCHORS = {AboveCrosshair=true, TopCenter=true, Center=true, TopLeft=true,
    TopRight=true, BottomLeft=true, BottomRight=true}
local FONTS = {FONT_HEADLINE_FACE=true, SMALL_FONT_FACE=true}

-- UE4SS loads modules with their filename as the Lua chunk source. Resolve from
-- this module, never from the game's working directory or a hardcoded Steam path.
local moduleSource = debug.getinfo(1, "S").source
local function configPath()
    local directory = moduleSource:match("^@(.+)[/\\][^/\\]+$")
    if not directory then return nil end
    local parent = directory:match("^(.*)[/\\][^/\\]+$")
    if not parent and directory:lower() == "scripts" then parent = "." end
    return parent and (parent .. "/config.json") or nil
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
function M.defaults() return copy(DEFAULTS) end

local function warn(log, field, reason)
    log("config warning: " .. field .. " " .. reason .. "; using default")
end
local function plainString(value, limit)
    return type(value)=="string" and #value>0 and #value<=limit and not value:find("%c")
end
local function validValue(key, value, default)
    if type(value) ~= type(default) then return false end
    if type(default)=="boolean" then return true end
    local range = RANGES[key]
    if range then
        return value==value and value>=range[1] and value<=range[2]
            and (not range[3] or value%1==0)
    end
    if COLORS[key] then return value:match("^%x%x%x%x%x%x$") ~= nil end
    if key=="ANCHOR" then return ANCHORS[value] == true end
    if key=="ACTION_KEY" or key=="TOGGLE_KEY" then
        -- Validate a single Unreal key-name token, not a keyboard chord or executable Lua.
        if key=="TOGGLE_KEY" and value=="" then return true end
        return #value<=64 and value:match("^[A-Za-z][A-Za-z0-9_]*$") ~= nil
    end
    if FONTS[key] then return plainString(value,64) end
    if key=="SMALL_FONT_PATH" or key=="SOUND_PATH" then
        return (key=="SOUND_PATH" and value=="")
            or (plainString(value,1024) and value:sub(1,1)=="/")
    end
    return false -- New non-boolean fields must declare a validation rule.
end
local function object(value)
    return type(value)=="table" and value~=json.null
        and (getmetatable(value) or {}).__jsontype=="object"
end

local function validated(values, log)
    local result = M.defaults()
    for key, default in pairs(DEFAULTS) do
        local value = values[key]
        if value ~= nil then
            if key=="TRIGGERS" then
                if object(value) then
                    for trigger, fallback in pairs(default) do
                        if value[trigger]~=nil then
                            if type(value[trigger])=="boolean" then result.TRIGGERS[trigger]=value[trigger]
                            else warn(log,"TRIGGERS." .. trigger,"must be true or false") end
                        end
                    end
                    for trigger in pairs(value) do
                        if default[trigger]==nil then log("config warning: unknown field TRIGGERS." .. tostring(trigger) .. "; ignored") end
                    end
                else warn(log,key,"must be a JSON object") end
            elseif validValue(key,value,default) then
                result[key] = COLORS[key] and value:upper() or value
            else warn(log,key,"has the wrong type, format, or range (see CONFIG.md)") end
        end
    end
    for key in pairs(values) do
        if DEFAULTS[key]==nil then log("config warning: unknown field " .. tostring(key) .. "; ignored") end
    end
    -- Never let a toggle press also dismiss an alert or start a restart hold.
    if result.TOGGLE_KEY:lower()==result.ACTION_KEY:lower() then
        result.TOGGLE_KEY=""
        log("config warning: TOGGLE_KEY matches ACTION_KEY; toggle shortcut disabled; choose different keys")
    end
    -- Fade times must fit within the selected status lifetime. Defaults always
    -- fit even with the shortest valid ALERT_MS, so no secondary clamping is needed.
    for _, key in ipairs({"FADE_IN_MS","FADE_OUT_MS"}) do
        if result[key] > result.ALERT_MS/3 then
            result[key] = DEFAULTS[key]
            warn(log,key,"must be at most one third of ALERT_MS")
        end
    end
    return result
end

local MAX_BYTES = 256 * 1024
local function readFile(path)
    local file, message, code = io.open(path,"rb")
    if not file then return nil,message,code end
    local text, readError = file:read(MAX_BYTES+1)
    local closed, closeError = file:close()
    if not text then return nil,readError or "empty file",0 end
    if not closed then return nil,closeError,0 end
    if #text>MAX_BYTES then return nil,"file exceeds 256 KiB",0 end
    return text
end

local function loadConfig(log, path)
    if not path then
        warn(log,"config.json","path could not be resolved from the mod's Scripts folder")
        return M.defaults()
    end
    local text, message, code = readFile(path)
    if not text and code==2 then -- ENOENT: missing file, not an unreadable existing file.
        local keys = {}
        for key in pairs(DEFAULTS) do keys[#keys+1]=key end
        table.sort(keys)
        local encoded = json.encode(DEFAULTS,{indent=true,keyorder=keys}) .. "\n"
        local file, writeError = io.open(path,"wb")
        if not file then
            warn(log,"config.json","could not be created at " .. path .. ": " .. tostring(writeError))
            return M.defaults()
        end
        local written, failure = file:write(encoded)
        local closed, closeError = file:close()
        if not written or not closed then
            warn(log,"config.json","could not be saved at " .. path .. ": " .. tostring(failure or closeError))
            return M.defaults()
        end
        log("config created with defaults: " .. path)
        -- Read the new file through exactly the same path as subsequent launches.
        text, message = readFile(path)
    end
    if not text then
        warn(log,"config.json","could not be read at " .. path .. ": " .. tostring(message) .. " (existing file left unchanged)")
        return M.defaults()
    end
    -- Accept the UTF-8 marker that some Windows editors add, without modifying the file.
    text = text:gsub("^\239\187\191", "")
    local decoded, position, decodeError = json.decode(text,1,json.null)
    if decodeError or not object(decoded) or text:sub(position or 1):find("%S") then
        warn(log,"config.json","is invalid: " .. tostring(decodeError or "expected one JSON object") .. " (file left unchanged)")
        return M.defaults()
    end
    local config = validated(decoded,log)
    log("config loaded: " .. path)
    return config
end

function M.load(log, path)
    -- Invalid JSON and I/O failures must not prevent the rest of the mod loading.
    local ok, result = pcall(loadConfig, log, path or configPath())
    if ok then return result end
    warn(log,"config.json","could not be loaded: " .. tostring(result) .. " (existing file left unchanged)")
    return M.defaults()
end
return M
