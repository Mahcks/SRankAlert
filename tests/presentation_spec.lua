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
assert(a.severity=="critical" and a.headline=="CIVILIAN KILLED")
a=P.events({event("CIVILIAN_KILLED","Civilian killed",false,1,true)})
assert(a.context:find("timing unknown",1,true))
assert(utf8.len(P.notice("test",string.rep("é",120)).context)==113)
print("presentation: hierarchy, severity, existing context, unknown timing and UTF-8 passed")

local burst={event("PENALTIES","Penalty: Team Kill",false)}
for i=1,4 do burst[#burst+1]=event("OBJECTIVE_FAILED","Objective failed: Rescue civilians "..i,false) end
local summary=P.events(burst)
assert(summary.headline=="Team Kill")
assert(summary.context:find("Rescue civilians",1,true))
assert(summary.context:find("+3 more",1,true) and #summary.context<=110)

local plain=P.events({event("PENALTIES","Penalty: Friendly Team Kill",false)})
assert(plain.headline=="Friendly Team Kill" and plain.context=="","penalty repeated headline")
local counted=P.events({event("PENALTIES","Penalty: Friendly Team Kill",false,2)})
assert(counted.context=="Count: 2","distinct count lost")
