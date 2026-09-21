local P=require("presentation")
local function event(category,label,warning,count,initial)
    return {category=category,label=label,warning=warning,count=count or 1,initial=initial}
end
local a=P.events({event("CIVILIAN_KILLED","Civilian killed",false)})
assert(a.headline=="CIVILIAN KILLED" and a.context=="" and a.severity=="critical")
a=P.events({event("CIVILIAN_INJURED","Civilian injured",true)})
assert(a.severity=="warning" and a.context:find("unconfirmed",1,true))
a=P.events({event("PLAYER_DIED","Player died: Alex",false,2)})
assert(a.headline=="PLAYER KILLED" and a.context=="Alex / Count: 2")
a=P.events({event("PENALTIES","Penalty: Unauthorized force",false)})
assert(a.headline=="Unauthorized force" and a.context=="")
a=P.events({event("CIVILIAN_INJURED","Civilian injured",true),event("CIVILIAN_KILLED","Civilian killed",false)})
assert(a.severity=="critical" and a.headline=="MULTIPLE INCIDENTS")
assert(a.context=="1 civilian killed / 1 injury warning")
a=P.events({event("CIVILIAN_KILLED","Civilian killed",false,1,true)})
assert(a.context:find("timing unknown",1,true))
assert(utf8.len(P.notice("test",string.rep("é",120)).context)==113)
print("presentation: hierarchy, severity, existing context, unknown timing and UTF-8 passed")

local burst={event("PENALTIES","Penalty: Team Kill",false)}
for i=1,4 do burst[#burst+1]=event("OBJECTIVE_FAILED","Objective failed: Rescue civilians "..i,false) end
local summary=P.events(burst)
assert(summary.headline=="MULTIPLE INCIDENTS")
assert(summary.context=="1 penalty: Team Kill / 4 objectives failed")

local plain=P.events({event("PENALTIES","Penalty: Friendly Team Kill",false)})
assert(plain.headline=="Friendly Team Kill" and plain.context=="","penalty repeated headline")
local counted=P.events({event("PENALTIES","Penalty: Friendly Team Kill",false,2)})
assert(counted.context=="Count: 2","distinct count lost")

-- The reported screenshot: a team-kill penalty, then two suspect-kill polls.
local penalty=event("PENALTIES","Penalty: Friendly Team Kill",false)
local kill=event("SUSPECT_KILLED","Suspect killed",false)
local split=P.merge(P.merge(P.events({penalty}),P.events({kill})),P.events({kill}))
local combined=P.events({penalty,event("SUSPECT_KILLED","Suspect killed",false,2)})
assert(split.context=="2 suspects killed / 1 penalty: Friendly Team Kill")
assert(split.headline==combined.headline and split.context==combined.context,"summary depends on polling batches")
assert(split.incidents.SUSPECT_KILLED.count==2 and split.incidents.PENALTIES.count==1)
local same=P.merge(P.events({kill}),P.events({kill}))
assert(same.headline=="SUSPECT KILLED" and same.context=="Count: 2","same-category repeats lost their meaning")
local original=P.events({kill}); P.merge(original,P.events({kill}))
assert(original.incidents.SUSPECT_KILLED.count==1,"merge mutated its input")
local warning=P.merge(P.events({event("CIVILIAN_INJURED","Civilian injured",true)}),P.events({event("REQUIRED_BONUS_LOST","Required bonus disabled: Bonus",true)}))
assert(warning.severity=="warning" and warning.context:find("warning",1,true))
local long={}
for _,category in ipairs({"CIVILIAN_KILLED","SUSPECT_KILLED","PLAYER_DIED","PENALTIES","OBJECTIVE_FAILED","CIVILIAN_INJURED","REQUIRED_BONUS_LOST"}) do
    long[#long+1]=event(category,"Penalty: "..string.rep("Long name ",15),false,123,true)
end
local limited=P.events(long)
assert(utf8.len(limited.context)<=110 and limited.context:find("timing unknown",1,true) and limited.context:find("types",1,true))
print("presentation aggregation: real category counts, batching independence, repeated kills, severity and bounded summaries passed")
