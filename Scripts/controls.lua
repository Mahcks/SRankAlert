local M={}
function M.new() return setmetatable({}, {__index=M}) end
function M:update(token, down, seconds, threshold, canRestart, tapSeconds)
    if token~=self.token then
        self.token,self.armed,self.pressed,self.fired,self.held=token,false,false,false,0
    end
    if not token or type(down)~="boolean" or type(seconds)~="number" then
        self.armed,self.pressed,self.held=false,false,0
        return
    end
    if not down then
        local dismiss=self.pressed and not self.fired and (self.held or 0)<=(tapSeconds or 0.3)
        self.armed,self.pressed,self.held=true,false,0
        if dismiss then return "dismiss" end
        return
    end
    if not self.armed or self.fired then return end
    self.pressed=true
    self.held=math.max(self.held or 0, seconds)
    if canRestart and seconds>=threshold then
        self.fired=true
        return "restart"
    end
end
return M
