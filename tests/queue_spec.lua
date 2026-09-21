local q=require("queue").new()
local function incident(n) return {sound=true,visual=require("presentation").events({
    {category="PENALTIES",label="Penalty: "..n,warning=false,count=1}})} end
q:push(incident("first")); assert(q:next().visual.headline=="first")
for i=1,100 do q:push(incident("incident "..i)) end
assert(#q.pending==1 and q.pending[1].visual.incidents.PENALTIES.count==100,"backlog count wrong")
local categories=0; for _ in pairs(q.pending[1].visual.incidents) do categories=categories+1 end
assert(categories==1,"unbounded category storage")
q:push({sound=false,visual={headline="status"}})
assert(q.pending[1].sound,"status replaced incident")
local old=q.generation
assert(q:finish(old)); assert(q:next().visual.headline=="PENALTIES RECORDED")
assert(q.current.visual.context=="Count: 100")
q:clear(); q:push(incident("new")); q:next()
assert(not q:finish(old) and q.current.visual.headline=="new")
print("queue: 100-bundle burst bounded, status priority, cancellation passed")
