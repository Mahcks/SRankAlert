local q=require("queue").new()
local function incident(n) return {sound=true,visual={headline=n,severity="critical"}} end
q:push(incident("first")); assert(q:next().visual.headline=="first")
for i=1,100 do q:push(incident("incident "..i)) end
assert(#q.pending==1 and q.pending[1].bundles==100,"unbounded backlog")
q:push({sound=false,visual={headline="status"}})
assert(q.pending[1].sound,"status replaced incident")
local old=q.generation
assert(q:finish(old)); assert(q:next().visual.headline=="MULTIPLE INCIDENTS")
q:clear(); q:push(incident("new")); q:next()
assert(not q:finish(old) and q.current.visual.headline=="new")
print("queue: 100-bundle burst bounded, status priority, cancellation passed")
