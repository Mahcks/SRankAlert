local Source = require("source")
local logs = {}
local pathReads = 0
Source.configure(function(msg) logs[#logs+1]=msg end, true)
local function obj(n)
    return { valid=true, GetFullName=function() pathReads=pathReads+1; error("unsafe path traversal") end,
        GetAddress=function(self) assert(self.valid); return n end,
        GetFName=function(self) assert(self.valid); return {ToString=function() return n end} end,
        IsValid=function(self) return self.valid end }
end
local world = obj("World Mission")
local hud = obj("HUD live"); hud.GetWorld=function() return world end
local mgr, gs = obj("ScoringManager live"), obj("GameState live")
mgr.GetWorld=function() return world end; gs.GetWorld=mgr.GetWorld
local wrongWorld = obj("World OldMission")
local stale = obj("ScoringManager old"); stale.GetWorld=function() return wrongWorld end
local cdo = obj("ScoringManager Default__ScoringManager"); cdo.GetWorld=mgr.GetWorld
FindAllOf = function(class)
    if class=="ScoringManager" then return {cdo,stale,mgr} end
    return {gs}
end
FindFirstOf=function() error("should prefer live same-world candidate") end
local function txt(s) return {ToString=function() return s end} end
local function wrapper(v) return {get=function() return v end} end
local kills, fail, partial = 0, false, false
mgr.GetSuspectCount=function(_,a,b,c,d)
    assert(next(a)==nil and next(b)==nil and next(c)==nil and next(d)==nil)
    if fail then error("synthetic reflection failure") end
    a.OutReported=0; a.OutArrested=0; a.OutTotal=8
    if not partial then a.OutKilled=kills end
end
mgr.GetCivilianCount=function(_,a,b,c,d,e)
    a.OutReported=0; b.Value=0; c[1]=0; d.OutArrested=0; e.OutTotal=2
end
mgr.bIsOfficialScoring=true
mgr.GetPenaltyScoreGroups=function() return {
    wrapper({GroupName=txt("ROE"),Score=-50,PenaltyCount=2}),
    wrapper({GroupName=txt("ROE"),Score=-50,PenaltyCount=1}),
    wrapper({GroupName=txt("Zero score"),Score=0,PenaltyCount=9})
} end
local component = obj("Component suspect")
mgr.GetScoreGroups=function() return {wrapper({GroupName=txt("Suspects"),Scores={
    wrapper({FromScoringComponent=component,Bonuses={wrapper({
        ScoreName=txt("Arrest"),bEnabled=true,bGiven=false,bRequired=true})}})
}})} end
local objective = obj("Objective Rescue"); objective.ObjectiveName=txt("Rescue"); objective.ObjectiveStatus=0
gs.MissionObjectives={objective}
local player = obj("PlayerState Alex"); player.GetWorld=mgr.GetWorld
player.bIsABot=false; player.Deaths=0; player.GetPlayerName=function() return "Alex" end
local bot = obj("PlayerState AI"); bot.GetWorld=mgr.GetWorld; bot.bIsABot=true; bot.Deaths=9
gs.PlayerArray={player,bot}
Source.reset(hud)
local s=Source.read()
assert(s.suspectKilled==0 and s.civilianKilled==0 and s.civilianInjured==0)
assert(s.penalties.ROE.count==3 and s.penalties["Zero score"]==nil and s.penaltiesComplete)
assert(s.objectives["Objective Rescue"].status==0)
assert(s.bonuses["Component suspect/Arrest"].enabled and #s.issues==0)
assert(s.players["PlayerState Alex"].deaths==0 and s.players["PlayerState AI"]==nil and s.playersComplete)
local firstEpoch=s.epoch
local before=#logs; Source.read(); assert(#logs==before, "healthy polls spam logs")
fail=true; s=Source.read(); assert(s.suspectKilled==nil)
before=#logs; Source.read(); assert(#logs==before, "failure logs repeat every poll")
player.Deaths=1; assert(Source.read().players["PlayerState Alex"].deaths==1)
player.Deaths=nil; s=Source.read(); assert(not s.playersComplete and s.players["PlayerState Alex"]==nil)
player.Deaths=1
fail=false; kills=1; s=Source.read(); assert(s.suspectKilled==1 and s.epoch==firstEpoch)
partial=true; s=Source.read(); assert(s.suspectKilled==nil, "partial read became zero")
partial=false
mgr.GetPenaltyScoreGroups=function() return {wrapper({GroupName=txt("ROE"),PenaltyCount=1})} end
s=Source.read(); assert(not s.penaltiesComplete and next(s.penalties)==nil)
mgr.bIsOfficialScoring=nil; s=Source.read(); assert(s.official==nil and #s.issues>0)
local joined=table.concat(logs,"\n")
assert(joined:find("GetSuspectCount call shape resolved",1,true))
assert(joined:find("GetCivilianCount call shape resolved",1,true))
assert(joined:find("GetPenaltyScoreGroups call shape resolved",1,true))
assert(joined:find("GetScoreGroups call shape resolved",1,true))
assert(joined:find("GetSuspectCount.OutKilled",1,true))
-- A dead scoring component can remain in a score-group snapshot; its Outer
-- chain must never be traversed, even inside pcall (native faults escape it).
component.valid=false
Source.read()
player.valid=false
Source.read()
mgr.valid=false
Source.read()
assert(pathReads==0,"source traversed UObject full paths")
-- Release mode keeps read failures visible without reflection-shape diagnostics.
package.loaded.source=nil
local quietSource=require("source")
logs={}
quietSource.configure(function(msg) logs[#logs+1]=msg end, false)
mgr.valid=true; component.valid=true; player.valid=true
quietSource.reset(hud)
quietSource.read()
joined=table.concat(logs,"\n")
assert(not joined:find("call shape resolved",1,true),"diagnostics leaked into release logging")
assert(not joined:find("score group ",1,true),"score diagnostics leaked into release logging")
assert(joined:find("could not read",1,true),"release logging hid read failures")
print("source: named/mixed outputs, wrappers, same-world lookup, partial reads, log latches passed")
