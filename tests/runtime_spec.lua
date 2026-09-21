-- Run the real main/source/toast modules with a deterministic engine model.
-- Every mocked UObject method asserts that it is on the game thread.
local function run(tier, probe, invalidConfig, restartChoice)
    for _, mod in ipairs({"source","diff","toast","queue","presentation"}) do package.loaded[mod]=nil end
    local time, scheduled, inGame, logs, allWidgets = 0, {}, false, {}, {}
    local invalidNameReads, fullPathReads = 0, 0
    local key, dismiss, notify
    local held=false
    local heldSeconds=0
    local host=true
    local restarts=0
    local function engine() assert(inGame, "engine access off game thread") end
    local function after(ms, fn, game)
        scheduled[#scheduled+1]={at=time+ms,fn=fn,game=game}
    end
    local function advance(to)
        local steps=0
        while true do
            table.sort(scheduled,function(a,b) return a.at<b.at end)
            if not scheduled[1] or scheduled[1].at>to then break end
            local task=table.remove(scheduled,1)
            time,inGame=task.at,task.game
            task.fn(); inGame=false
            steps=steps+1; assert(steps<10000,"runaway scheduling")
        end
        time=to
    end
    local function object(n)
        return { valid=true, GetFullName=function(self)
                engine(); fullPathReads=fullPathReads+1; error("unsafe full path traversal") end,
            GetAddress=function(self)
                engine(); if not self.valid then invalidNameReads=invalidNameReads+1; error("invalid address read") end
                return n end,
            IsValid=function(self) engine(); return self.valid end,
            GetFName=function() engine(); return {ToString=function() engine(); return n end} end }
    end
    local function text(n) return {ToString=function() engine(); return n end} end
    local world=object("World first")
    local root=object("Overlay"); root.children={}
    root.GetChildrenCount=function(self) engine(); return #self.children end
    root.GetChildAt=function(self,i) engine(); return self.children[i+1] end
    root.RemoveChild=function(self,c)
        engine(); for i,x in ipairs(self.children) do if x==c then table.remove(self.children,i); return true end end
        return false
    end
    root.AddChildToOverlay=function(self,c)
        engine(); self.children[#self.children+1]=c
        return {SetHorizontalAlignment=function(_,v) engine(); self.horizontal=v end,
            SetVerticalAlignment=engine,SetPadding=engine}
    end
    local hud=object("HUD first"); hud.GetWorld=function() engine(); return world end
    local function owningPlayer()
        engine()
        local pc=object("Controller")
        pc.IsInputKeyDown=function() engine(); return held end
        pc.GetInputKeyTimeDown=function() engine(); return heldSeconds end
        pc.IsLocalController=function() engine(); return true end
        pc.HasAuthority=function() engine(); return host end
        return pc
    end
    hud.GetOwningPlayer=owningPlayer
    hud.PlaySound=engine
    local mgr,gs=object("Manager"),object("State")
    mgr.GetWorld=hud.GetWorld; gs.GetWorld=hud.GetWorld
    mgr.bIsOfficialScoring=true
    local kills, civilian, penalty=0,0,0
    mgr.GetSuspectCount=function(_,a,b,c,d)
        engine(); a.OutReported=0; a.OutArrested=0; a.OutKilled=kills; a.OutTotal=5
    end
    mgr.GetCivilianCount=function(_,a,b,c,d,e)
        engine(); a.OutReported=0; a.OutInjured=0; a.OutKilled=civilian; a.OutArrested=0; a.OutTotal=2
    end
    mgr.GetScoreGroups=function() engine(); return {} end
    mgr.GetPenaltyScoreGroups=function()
        engine(); if penalty==0 then return {} end
        return {{GroupName=text("Unauthorized force"),Score=-50,PenaltyCount=penalty}}
    end
    gs.MissionObjectives={}
    local player=object("PlayerState Alex"); player.GetWorld=hud.GetWorld
    player.bIsABot=false; player.Deaths=0
    player.GetPlayerName=function() engine(); return "Alex" end
    gs.PlayerArray={player}
    FindAllOf=function(class)
        engine(); if class=="ScoringManager" then return {mgr} end
        if class=="ReadyOrNotGameState" then return {gs} end
        return {hud}
    end
    FindFirstOf=function() engine() end
    StaticFindObject=function(path) engine(); return object(path) end
    StaticConstructObject=function(class,outer,n)
        engine(); local w=object(n or ("Widget"..#allWidgets+1)); w.children={}; w.Font={Size=24,OutlineSettings={}}; w.WidgetStyle={BackgroundImage={TintColor={}},FillImage={TintColor={}}}
        w.SetVisibility=function(self,v) engine(); self.visibility=v end
        w.SetHeightOverride=function(self,v) engine(); self.height=v end; w.SetIsMarquee=engine; w.SetFillColorAndOpacity=function(self,v) engine(); self.fillColor=v end;
        w.SetPercent=function(self,v) engine(); self.percent=v end;
        w.SetClipping=function(self,v) engine(); self.clipping=v end; w.SetJustification=engine; w.SetShadowOffset=engine; w.SetShadowColorAndOpacity=engine; w.SetUserSpecifiedScale=engine; w.SetPadding=engine; w.SetBrushColor=function(self,v) engine(); self.brushColor=v end
        w.SetFont=function(self,f) engine(); self.Font=f end
        w.SetColorAndOpacity=engine; w.SetAutoWrapText=function(self,v) engine(); self.wrap=v end
        w.SetWidthOverride=function(self,v) engine(); self.width=v end
        w.SetRenderOpacity=function(self,v) engine(); self.opacity=v end
        w.SetRenderTranslation=function(self,v) engine(); self.translation=v end
        w.AddChildToOverlay=function(self,c)
            engine(); self.children[#self.children+1]=c
            local slot={}
            slot.SetHorizontalAlignment=function(self,v) engine(); self.horizontal=v end
            slot.SetVerticalAlignment=function(self,v) engine(); self.vertical=v end
            slot.SetPadding=function(self,v) engine(); self.padding=v end
            c.slot=slot
            return slot
        end
        w.AddChildToVerticalBox=w.AddChildToOverlay
        w.AddChildToHorizontalBox=w.AddChildToOverlay
        w.AddChild=function(self,c) engine(); self.child=c; return {} end
        w.SetText=function(self,t) engine(); self.text=t end
        w.RemoveFromParent=function(self) engine(); root:RemoveChild(self) end
        allWidgets[#allWidgets+1]=w
        return w
    end
    FName=function(s) engine(); return s end
    FText=function(s) engine(); return s end
    Key={F6=6,F9=9}; ModifierKey={CONTROL=1}
    RegisterKeyBind=function(k,mods,fn) if fn then key=fn else dismiss=mods end end
    IsKeyBindRegistered=function() return false end
    NotifyOnNewObject=function(_,fn) notify=fn end
    IsInGameThread=function() return inGame end
    ExecuteInGameThreadWithDelay=nil; ExecuteWithDelay=nil; ExecuteInGameThread=nil
    if tier=="delayed" then ExecuteInGameThreadWithDelay=function(ms,fn) after(ms,fn,true) end
    elseif tier=="composed" then
        ExecuteWithDelay=function(ms,fn) after(ms,fn,false) end
        ExecuteInGameThread=function(fn) after(0,fn,true) end
    end
    local realPrint=print
    print=function(s) logs[#logs+1]=s end
    local f=assert(io.open("Scripts/main.lua","r")); local code=f:read("*a"); f:close()
    -- Use the real JSON loader, with files isolated from both the checkout and game.
    local Config = require("sra_config")
    local originalLoad = Config.load
    local configPath = TEST_TMP .. "/runtime-" .. tier .. tostring(probe) .. tostring(invalidConfig) .. tostring(restartChoice) .. ".json"
    if probe or invalidConfig or restartChoice ~= nil then
        local file=assert(io.open(configPath,"wb"))
        file:write(probe and '{"FONT_PROBE":true}'
            or invalidConfig == "json" and '{"RESTART_ENABLED":true, broken'
            or invalidConfig and '{"POLL_MS":-5,"CRITICAL_COLOR":"oops","RESTART_ENABLED":null}'
            or ('{"RESTART_ENABLED":' .. tostring(restartChoice) .. '}'))
        file:close()
    end
    Config.load=function(log) return originalLoad(log,configPath) end
    assert(load(code))()
    Config.load=originalLoad
    if invalidConfig ~= "json" then
        assert(table.concat(logs,"\n"):find("config loaded:",1,true),"main did not load its JSON config")
    end
    if invalidConfig == "json" then
        assert(table.concat(logs,"\n"):find("config warning: config.json",1,true))
    elseif invalidConfig then
        for _,field in ipairs({"POLL_MS","CRITICAL_COLOR","RESTART_ENABLED"}) do
            assert(table.concat(logs,"\n"):find("config warning: " .. field,1,true),"missing config warning: " .. field)
        end
    end
    if tier=="none" then
        assert(#scheduled==0 and #allWidgets==0 and notify==nil)
        print=realPrint; return
    end
    dismiss=function()
        held,heldSeconds=true,0.1; advance(time+50)
        held,heldSeconds=false,0; advance(time+50)
    end
    advance(0); assert(#allWidgets==0,"attached before root populated")
    hud.CanvasPanel_Root=root
    advance(250); assert(#root.children==1,"did not retry attachment")
    local fontLog=table.concat(logs,"\n")
    assert((fontLog:find("small text font readback:",1,true) ~= nil) == (probe == true),
        "font diagnostics must be silent by default and available to the probe")
    local function shown()
        local c=root.children[1]
        if not c or c.visibility~=3 then return "" end
        local function collect(w)
            if w.visibility==1 then return "" end
            local parts={w.text or ""}
            if w.child then parts[#parts+1]=collect(w.child) end
            for _, child in ipairs(w.children or {}) do parts[#parts+1]=collect(child) end
            return table.concat(parts," ")
        end
        return collect(c)
    end
    if probe then
        advance(6000)
        assert(shown():find("abcdefghijklmnopqrstuvwxyz",1,true),"specimen not displayed")
        local checked=0
        for _,w in ipairs(allWidgets) do
            if w.text and w.text:find("abcdefghijklmnopqrstuvwxyz",1,true) then
                assert(w.Font.FontObject and w.Font.LetterSpacing==25,"candidate font not applied")
                assert(w.Font.TypefaceFontName=="Regular")
                checked=checked+1
            end
        end
        assert(checked==2,"both final sizes not sampled")
        advance(15000); assert(shown():find("FONT TEST",1,true),"probe auto-dismissed")
        print=realPrint; realPrint("font probe: candidate asset, tracking, two sizes, persistent specimen passed")
        return
    end
    assert(root.horizontal==2,"toast not centered horizontally")
    assert(root.children[1].translation.Y==-140,"toast not above crosshair")
    assert(root.children[1].child.width==420,"toast width not bounded")
    advance(340); assert(root.children[1].opacity>0 and root.children[1].opacity<1,"fade-in absent")
    advance(430); assert(root.children[1].opacity==1)
    assert(shown():find("STATUS:",1,true),"status relies on color")
    assert(shown():find("ACTIVE",1,true))
    assert(shown():find("DISMISS",1,true),"startup omitted control instructions")
    kills=1; advance(600)
    assert(shown():find("SUSPECT KILLED",1,true),"health notice delayed first violation")
    assert(shown():find("DISMISS",1,true),"incident omitted dismiss prompt")
    assert(shown():find("INCIDENT:",1,true),"incident relies on color")
    for _,w in ipairs(allWidgets) do
        if w.text and w.text:find("DISMISS",1,true) then
            assert(w.Font.FontObject and w.Font.LetterSpacing==25,"real hints missed verified font")
            assert(w.Font.TypefaceFontName=="Regular" and w.Font.Size==13)
        end
    end
    local glyphs=0
    for _,w in ipairs(allWidgets) do
        if w.text=="F9" then
            glyphs=glyphs+1
            assert(w.Font.Size==16 and w.Font.TypefaceFontName=="Bold","glyph font incorrect")
        end
        if w.percent then assert(w.percent==0 and w.visibility==1,"resting tile was filled") end
    end
    assert(glyphs==2,"two F9 tiles missing")
    local column=root.children[1].child.child
    assert(column.children[1].text:find("INCIDENT:",1,true))
    assert(column.children[2].height==10,"divider missing top clearance")
    assert(column.children[3].height==1 and column.children[3].width==64,"divider row misplaced")
    assert(column.children[4].height==6,"divider missing bottom clearance")
    local row=column.children[6]
    assert(#row.children==2 and row.children[1].width==170 and row.children[2].width==170,
        "control row not compact")
    for _,w in ipairs(allWidgets) do
        if w.text=="DISMISS" or w.text=="HOLD TO RESTART" then
            assert(w.wrap==false and not w.text:find("\n"),"inconsistent label wrapping")
            assert(w.Font.OutlineSettings.OutlineSize==2,"label outline missing")
            assert(w.Font.OutlineSettings.OutlineColor.A==1,"outline not opaque")
        end
    end
    local first=shown()
    civilian=1; penalty=1; advance(950)
    assert(shown():find("MULTIPLE INCIDENTS",1,true),"burst not merged")
    advance(5950); assert(root.children[1].opacity==1,"persistent warning faded")
    advance(11600); assert(shown()~="","incident auto-dismissed")
    dismiss()
    local oldWidgets=#allWidgets
    advance(14000); assert(shown()=="" and #allWidgets==oldWidgets,"level-triggered popup/widget allocation")
    kills=2; advance(14500)
    advance(20000); dismiss(); advance(20500); assert(shown()=="")
    -- A new HUD in the same world must preserve the existing diff baseline.
    hud.valid=false
    hud=object("HUD respawn"); hud.GetWorld=function() engine(); return world end
    hud.CanvasPanel_Root=root; hud.PlaySound=engine; hud.GetOwningPlayer=owningPlayer
    notify(hud); advance(20500)
    advance(21500); assert(shown()=="","HUD recreation replayed mission events")
    mgr.bIsOfficialScoring=false; kills=3; advance(22000)
    assert(shown():find("INCOMPLETE",1,true) and not shown():find("SUSPECT KILLED",1,true))
    mgr.bIsOfficialScoring=true; advance(22500)
    assert(not shown():find("SUSPECT KILLED",1,true),"unofficial scoring changes replayed")
    player.Deaths=1; advance(22600)
    assert(shown():find("PLAYER KILLED",1,true) and shown():find("Alex",1,true),"player death did not alert")
    mgr.bIsOfficialScoring=false; player.Deaths=2
    advance(28100)
    assert(shown():find("PLAYER KILLED",1,true),"unofficial scoring suppressed factual player death")
    -- A confirmed new world resets the baseline and cancels old dismissals.
    world.valid=false; world=object("World second")
    hud.valid=false; hud=object("HUD second")
    hud.GetWorld=function() engine(); return world end; hud.CanvasPanel_Root=root; hud.GetOwningPlayer=owningPlayer
    mgr.GetWorld=hud.GetWorld; gs.GetWorld=hud.GetWorld
    kills,civilian,penalty=0,0,0
    player.GetWorld=hud.GetWorld; player.Deaths=0; mgr.bIsOfficialScoring=true
    notify(hud); advance(28100)
    kills=1; advance(28450)
    assert(shown():find("SUSPECT KILLED",1,true),"new mission did not rearm")
    advance(33800); dismiss(); advance(33950); assert(shown()=="")
    -- The same notification delivered twice must not start a second loop.
    local before=#allWidgets
    notify(hud); notify(hud); advance(33950)
    assert(#allWidgets==before)
    -- Dismiss cancels the current toast's timer, retains queued alerts,
    -- and does not disable subsequent observations.
    kills=2; advance(34300)
    civilian=1; advance(34650)
    assert(shown():find("MULTIPLE INCIDENTS",1,true),"later incident not merged")
    advance(39800); assert(shown()~="","merged warning expired")
    dismiss(); assert(shown()=="","dismiss left stale incident queued")
    kills=3; advance(40000)
    assert(shown():find("SUSPECT KILLED",1,true),"dismiss disabled detection")
    local mode=object("Mode")
    mode.HasAuthority=function() engine(); return true end
    mode.RestartGame=function() engine(); restarts=restarts+1 end
    world.AuthorityGameMode=mode
    advance(40100)
    if restartChoice ~= true then
        assert(not shown():find("HOLD TO RESTART",1,true),"disabled restart hint appeared")
        assert(table.concat(logs,"\n"):find("restart disabled",1,true),"startup log misstates restart availability")
        held,heldSeconds=true,3.1; advance(40200)
        assert(restarts==0,"disabled restart fired for the host")
        held,heldSeconds=false,0; advance(40300)
        assert(shown()~="","long hold dismissed the incident")
        dismiss(); assert(shown()=="","tap-to-dismiss stopped working with restart off")
        assert(invalidNameReads==0 and fullPathReads==0)
        print=realPrint
        realPrint("runtime "..tier..": default/disabled/invalid config cannot restart; dismiss remains active")
        return
    end
    assert(shown():find("HOLD TO RESTART",1,true),"opted-in restart hint missing")
    held,heldSeconds=true,3.1; host=false; advance(40200)
    assert(restarts==0,"client restarted")
    held,heldSeconds=false,0; advance(40300)
    kills=4; host=true; advance(40700)
    held,heldSeconds=true,0.75; advance(40750)
    local function getFill()
        local row=root.children[1].child.child.children[6]
        local layers=row.children[2].child.children[1].child
        assert(layers.clipping==1,"tile not clipped")
        local rect=layers.children[2]
        assert(rect.clipping==1,"fill not clipped")
        assert(rect.height==nil and rect.slot.vertical==0,
            "fill must stretch with the arranged tile height, not stop at a fixed height")
        local inset=rect.slot.padding
        assert(inset.Top==layers.children[3].height and inset.Bottom==layers.children[4].height
            and inset.Left==layers.children[5].width and inset.Right==layers.children[6].width,
            "fill insets must meet the inner edges of all four border strokes")
        assert(layers.children[#layers.children].text=="F9","glyph is not above fill")
        return rect
    end
    local earlyBar=getFill()
    assert(earlyBar.width==8.5 and earlyBar.child.opacity==1 and earlyBar.visibility==3,
        "quarter-fill geometry incorrect")
    held,heldSeconds=true,1.5; advance(40800)
    local bar=getFill()
    assert(bar.child.brushColor.R==1 and bar.child.brushColor.A==1,"fill lost bold color")
    assert(bar.width==17,"half-fill geometry incorrect")
    assert(restarts==0,"restarted before 3 seconds")
    held,heldSeconds=false,0; advance(40850)
    assert(shown()~="","cancelled hold dismissed incident")
    assert(bar.width==0,"cancelled progress lingered")
    held,heldSeconds=true,1.5; advance(40900)
    assert(bar.width==17,"second hold failed to show progress")
    held,heldSeconds=true,2.7; advance(40950)
    assert(math.abs(bar.width-30.6)<0.001,"90 percent width incorrect")
    assert(restarts==0,"restart triggered at 90 percent")
    held,heldSeconds=true,3.1; advance(41000)
    assert(restarts==1,"host hold failed")
    advance(41000); assert(restarts==1,"restart repeated")
    assert(bar.width==0,"completed hold progress did not reset")
    assert(invalidNameReads==0,"invalid UObject was named before validity check")
    assert(fullPathReads==0,"runtime used unsafe full path traversal")
    print=realPrint
    realPrint("runtime "..tier..": game-thread guards, attach retry, queue, toggles, world changes passed")
end
run("delayed",false,false,true); run("composed",false,false,true); run("none")

run("delayed",true)
run("delayed"); run("composed")
run("delayed",false,false,false)
run("delayed",false,true)
run("delayed",false,"json")
