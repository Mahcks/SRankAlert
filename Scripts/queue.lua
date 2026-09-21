-- One toast at a time. A poll batches simultaneous observations into one
-- event bundle so a kill and its recorded penalty are not separate popups.
local M = {}
local Presentation = require("presentation")
function M.new()
    local self = { pending = {}, current = nil, generation = 0 }
    function self:push(message)
        local pending = self.pending[1]
        if not pending then self.pending[1] = message; return end
        if not message.sound then
            if not pending.sound then self.pending[1] = message end
            return
        end
        if not pending.sound then self.pending[1] = message; return end
        self.pending[1] = {sound=true, visual=Presentation.merge(pending.visual, message.visual)}
    end
    function self:clear()
        self.pending, self.current = {}, nil
        self.generation = self.generation + 1
    end
    function self:next()
        if self.current then return nil end
        self.current = table.remove(self.pending, 1)
        return self.current
    end
    function self:finish(generation)
        if generation ~= self.generation then return false end
        self.current = nil
        return true
    end
    return self
end
return M
