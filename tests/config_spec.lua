local Config = require("sra_config")
local json = require("sra_dkjson")
local path = TEST_TMP .. "/config.json"
local logs = {}
local function log(message) logs[#logs+1]=message end
local function read()
    local file=assert(io.open(path,"rb")); local value=file:read("*a"); file:close(); return value
end
local function write(value)
    local file=assert(io.open(path,"wb")); assert(file:write(value)); assert(file:close())
end
local function loadUnchanged(text)
    write(text); logs={}
    local config=Config.load(log,path)
    assert(read()==text,"loading rewrote an existing config")
    return config
end
local function warning(field)
    assert(table.concat(logs,"\n"):find("config warning: " .. field,1,true),"warning missing for " .. field)
end

-- A first load creates readable JSON with every default, then reads that file.
local fresh=Config.load(log,path)
local disk,_,err=json.decode(read(),1,json.null)
assert(not err and disk.ACTION_KEY=="F9" and disk.RESTART_ENABLED==true)
local function same(a,b)
    if type(a)~="table" then assert(a==b); return end
    for key,value in pairs(a) do same(value,b[key]) end
    for key in pairs(b) do assert(a[key]~=nil) end
end
same(Config.defaults(),disk); same(fresh,disk)
assert(disk.TOGGLE_KEY=="F8")
for _, field in ipairs({"FONT_PROBE", "VERBOSE", "DIAGNOSTICS"}) do
    assert(disk[field] == false, field .. " must default off in a release")
end
assert(disk.FONT_CONTEXT_FACE==nil and disk.FONT_CONTROL_FACE==nil,"removed font fields were generated")
assert(table.concat(logs,"\n"):find("config created with defaults:",1,true))
assert(table.concat(logs,"\n"):find("config loaded:",1,true))

-- False overrides are retained and nested missing fields inherit their own defaults.
local saved='{"ACTION_KEY":"F11","RESTART_ENABLED":false,"SCALE":1.25,"TRIGGERS":{"CIVILIAN_INJURED":true,"PLAYER_DIED":false}}'
local config=loadUnchanged(saved)
assert(config.ACTION_KEY=="F11" and config.RESTART_ENABLED==false and config.SCALE==1.25)
assert(config.TRIGGERS.CIVILIAN_INJURED==true and config.TRIGGERS.PLAYER_DIED==false)
assert(config.TRIGGERS.SUSPECT_KILLED==true and config.POLL_MS==350 and #logs==1)
same(config,Config.load(log,path)) -- another launch preserves all edits

-- Fresh/missing settings default on; invalid values and broken files disable restart.
config=loadUnchanged('{"RESTART_ENABLED":false}')
assert(config.RESTART_ENABLED==false,"explicit opt-out was lost")
config=loadUnchanged('{"RESTART_ENABLED":true}')
assert(config.RESTART_ENABLED==true,"explicit true was lost")
config=loadUnchanged('{}'); assert(config.RESTART_ENABLED==true)
for _, text in ipairs({ '{"RESTART_ENABLED":"false"}', '{"RESTART_ENABLED":0}',
    '{"RESTART_ENABLED":null}', '{"RESTART_ENABLED":false, broken'}) do
    config=loadUnchanged(text)
    assert(config.RESTART_ENABLED==false,"invalid config enabled restart")
end

-- Older files remain readable and untouched; removed options cannot re-enter the active config.
config=loadUnchanged('{"TOGGLE_KEY":"F10"}')
assert(config.TOGGLE_KEY=="F10")
config=loadUnchanged('{"TOGGLE_KEY":"Ctrl+F8"}')
assert(config.TOGGLE_KEY=="F8"); warning("TOGGLE_KEY")
config=loadUnchanged('{"TOGGLE_KEY":""}')
assert(config.TOGGLE_KEY=="")
config=loadUnchanged('{"TOGGLE_KEY":"f9"}')
assert(config.TOGGLE_KEY==""); warning("TOGGLE_KEY")
config=loadUnchanged('{"ACTION_KEY":"F8"}')
assert(config.ACTION_KEY=="F8" and config.TOGGLE_KEY==""); warning("TOGGLE_KEY")

config=loadUnchanged('{"FONT_CONTEXT_FACE":"Bold","FONT_CONTROL_FACE":"Bold","SCALE":1.25}')
assert(config.FONT_CONTEXT_FACE==nil and config.FONT_CONTROL_FACE==nil and config.SCALE==1.25)
assert(table.concat(logs,"\n"):find("unknown field FONT_CONTEXT_FACE",1,true))
assert(table.concat(logs,"\n"):find("unknown field FONT_CONTROL_FACE",1,true))

-- Exercise every field's type validation, including all nested switches.
for field,default in pairs(Config.defaults()) do
    config=loadUnchanged(json.encode({[field]=json.null}))
    if field=="RESTART_ENABLED" then assert(config[field]==false) else same(default,config[field]) end
    warning(field)
end
for field,default in pairs(Config.defaults().TRIGGERS) do
    config=loadUnchanged(json.encode({TRIGGERS={[field]=0}}))
    assert(config.TRIGGERS[field]==default); warning("TRIGGERS." .. field)
end

config=loadUnchanged('{"POLL_MS":-1,"SCALE":1e999,"KEY_TILE_SIZE":10000,"HEADLINE_SIZE":12.5,"CRITICAL_COLOR":"#nope","ANCHOR":"Offscreen","ACTION_KEY":"Ctrl+F9","TRIGGERS":{"PLAYER_DIED":null}}')
for _,field in ipairs({"POLL_MS","SCALE","KEY_TILE_SIZE","HEADLINE_SIZE","CRITICAL_COLOR","ANCHOR","ACTION_KEY"}) do
    assert(config[field]==Config.defaults()[field]); warning(field)
end
warning("TRIGGERS.PLAYER_DIED")
config=loadUnchanged('{"ALERT_MS":1000,"FADE_IN_MS":500,"FADE_OUT_MS":500}')
assert(config.FADE_IN_MS==180 and config.FADE_OUT_MS==300)
warning("FADE_IN_MS"); warning("FADE_OUT_MS")
config=loadUnchanged('{"CRITICAL_COLOR":"abcdef","SCALE":0.5,"RESTART_HOLD_SECONDS":5,"TRIGGERS":{}}')
assert(config.CRITICAL_COLOR=="ABCDEF" and config.SCALE==0.5 and config.RESTART_HOLD_SECONDS==5)
assert(config.TRIGGERS.PLAYER_DIED and #logs==1)
config=loadUnchanged('{"SCLALE":2,"TRIGGERS":{"TYPO":true}}')
assert(config.SCALE==1 and table.concat(logs,"\n"):find("unknown field SCLALE",1,true))
assert(table.concat(logs,"\n"):find("unknown field TRIGGERS.TYPO",1,true))
config=loadUnchanged('\239\187\191{"ACTION_KEY":"F12"}')
assert(config.ACTION_KEY=="F12")
for _,text in ipairs({'{ broken','{"SCALE":','[]','null','true','{} trailing','{"TRIGGERS":[]}','{"TRIGGERS":null}',string.rep(' ',256*1024+1)}) do
    config=loadUnchanged(text)
    local expected=Config.defaults()
    if not text:find("TRIGGERS",1,true) then expected.RESTART_ENABLED=false end
    same(config,expected)
    assert(#logs>0 and table.concat(logs,"\n"):find("config warning:",1,true))
end
config=loadUnchanged('{}'); config.TRIGGERS.PLAYER_DIED=false
assert(Config.defaults().TRIGGERS.PLAYER_DIED,"validation mutated shared defaults")

-- Access denied must never be mistaken for a missing file and opened for writing.
local realOpen=io.open
local modes={}
io.open=function(_,mode) modes[#modes+1]=mode; return nil,"Permission denied",13 end
logs={}; config=Config.load(log,path)
io.open=realOpen
local expected=Config.defaults(); expected.RESTART_ENABLED=false; same(config,expected); warning("config.json")
assert(#modes==1 and modes[1]=="rb","attempted to overwrite an unreadable file")

-- First-run write failures fall back without taking down the mod.
io.open=function(_,mode)
    if mode=="rb" then return nil,"No such file",2 end
    return nil,"Permission denied",13
end
logs={}; config=Config.load(log,path); io.open=realOpen
local expected=Config.defaults(); expected.RESTART_ENABLED=false; same(config,expected); warning("config.json")

-- UE4SS supplies an @filename chunk name. Resolve Windows/Unix-style paths
-- relative to the module, independent of the process's working directory.
local moduleFile=assert(io.open("Scripts/sra_config.lua","rb"))
local moduleCode=moduleFile:read("*a"); moduleFile:close()
for _,location in ipairs({"C:\\Games\\Ready Or Not\\ue4ss\\Mods\\SRankAlert\\Scripts\\sra_config.lua",
    "D:/Steam Library/ue4ss/Mods/SRankAlert/Scripts/sra_config.lua"}) do
    local module=assert(load(moduleCode,"@" .. location))()
    local visited
    io.open=function(file) visited=file; return nil,"Permission denied",13 end
    module.load(log); io.open=realOpen
    local expected=location:match("^(.*)[/\\]Scripts[/\\]") .. "/config.json"
    assert(visited==expected,"config path depended on working directory")
end
print("config: first-run JSON, persistence, missing/nested fields, all field types, ranges, malformed files, read/write failures and path resolution passed")
