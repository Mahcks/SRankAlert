local Diff = require("diff")
local cfg = { CIVILIAN_KILLED=true, SUSPECT_KILLED=true, PENALTIES=true,
    OBJECTIVE_FAILED=true, CIVILIAN_INJURED=false, REQUIRED_BONUS_LOST=true, PLAYER_DIED=true }
local function snap(epoch, c, s, penalties)
    return { epoch=epoch, civilianKilled=c, suspectKilled=s, penalties=penalties or {},
        penaltiesComplete=true, objectives={} }
end
local d = Diff.new(cfg)
assert(#d:update(snap(1,0,0)) == 0)
local events = d:update(snap(1,1,0))
assert(#events == 1 and events[1].count == 1 and not events[1].initial)
assert(#d:update(snap(1,1,0)) == 0, "stable values repeat")
events = d:update(snap(1,4,2))
assert(#events == 2 and events[1].count == 3 and events[2].count == 2, "batched increments lost")
assert(#d:update(snap(1,nil,nil)) == 0)
assert(#d:update(snap(1,4,2)) == 0, "missing read rearmed counters")
local _, issues = d:update(snap(1,0,0))
assert(issues.civilianKilled and #d:update(snap(1,4,2)) == 0, "rollback replayed event")
events = d:update(snap(1,5,2))
assert(#events == 1 and events[1].count == 1)
assert(#d:update(snap(2,0,0)) == 0, "new mission inherited counters")
assert(#d:update(snap(2,1,0)) == 1)
events = d:update(snap(3,3,0))
assert(events[1].initial and events[1].count == 3, "late join must say timing unknown")
local penalties = { ["Unauthorized force"]={name="Unauthorized force",count=2} }
events = d:update(snap(3,3,0,penalties))
assert(#events == 1 and events[1].count == 2 and not events[1].initial)
assert(#d:update(snap(3,3,0,penalties)) == 0)
assert(#d:update(snap(3,3,0,{})) == 0)
assert(#d:update(snap(3,3,0,penalties)) == 0, "absent penalty replayed")
local s = snap(3,3,0,penalties)
s.objectives = { O={name="Rescue",status=0} }
d:update(s)
s.objectives.O.status = 2
events = d:update(s)
assert(#events == 1 and not events[1].initial)
s.objectives.O.status = 0; d:update(s)
s.objectives.O.status = 2
assert(#d:update(s) == 0, "objective status rollback replayed")
s.civilianInjured = 1
assert(#d:update(s) == 0, "injury enabled by default")
s.bonuses = { C={name="Arrest",required=true,enabled=true,given=false} }
d:update(s)
s.bonuses.C = {name="Arrest",required=true,enabled=false,given=false}
events = d:update(s)
assert(#events == 1 and events[1].warning, "unverified bonus should only warn")
local partial = Diff.new(cfg)
s = snap(1,0,0); s.penaltiesComplete=false; partial:update(s)
s.penalties = penalties
assert(partial:update(s)[1].initial, "partial array assumed absent entries were zero")
local p=Diff.new(cfg)
s=snap(1,0,0); s.players={Alex={name="Alex",deaths=0},Bob={name="Bob",deaths=0}}
assert(#p:update(s)==0)
s.players.Alex.deaths=1
events=p:update(s)
assert(#events==1 and events[1].category=="PLAYER_DIED" and not events[1].initial)
assert(#p:update(s)==0)
s.players=nil; p:update(s)
s.players={Alex={name="Renamed Alex",deaths=1},Bob={name="Bob",deaths=1}}
events=p:update(s); assert(#events==1 and events[1].label=="Player died: Bob")
s.players.Alex.deaths=0; p:update(s)
s.players.Alex.deaths=1; assert(#p:update(s)==0,"player rollback repeated death")
s.players.Alex.deaths=3
events=p:update(s); assert(#events==1 and events[1].count==2)
print("diff: transitions, jumps, unknowns, rollback, epochs, penalties, objectives, optional warnings passed")
