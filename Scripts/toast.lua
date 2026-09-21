-- Owned viewport overlay; its lifetime is independent of the character HUD.
-- Every entry point and animation callback runs on the game thread.
local M = {}
local PREFIX, pinned, serial = "SRA_Toast_", {}, 0
local TILE_BORDER = 3 -- Shared by the outline and the fill's inner bounds.
local seed = tostring({}):gsub("[^%w]", "") .. tostring(math.floor(os.clock() * 1000))
local ANCHORS = { TopRight={3,1}, TopLeft={1,1}, BottomRight={3,3}, BottomLeft={1,3},
    TopCenter={2,1}, Center={2,2}, AboveCrosshair={2,2} }
local function try(fn) local ok, v = pcall(fn); if ok then return v end end
local function valid(o) return o and try(function() return o:IsValid() end) == true end
local function fname(value)
    pinned[#pinned + 1] = value
    return FName(pinned[#pinned])
end
local function construct(kind, outer, named)
    local class = StaticFindObject("/Script/UMG." .. kind)
    assert(valid(class), "UMG class unavailable: " .. kind)
    if not named then return assert(StaticConstructObject(class, outer), kind .. " construction failed") end
    serial = serial + 1
    return assert(StaticConstructObject(class, outer, fname(PREFIX .. seed .. "_" .. serial)), kind .. " construction failed")
end
local function linear(hex, alpha)
    hex = tostring(hex):gsub("#", "")
    assert(hex:match("^%x%x%x%x%x%x$"), "invalid configured color: " .. hex)
    -- Config uses display-space hex. Unreal brush colors are linear.
    local function channel(at)
        local v = tonumber(hex:sub(at, at + 1), 16) / 255
        return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
    end
    return { R=channel(1), G=channel(3), B=channel(5), A=alpha or 1 }
end
-- Boost saturation/value in display space while preserving the severity hue.
local function vivid(hex, saturation, brightness)
    local rgb={}
    for i=1,3 do rgb[i]=tonumber(hex:sub(i*2-1,i*2),16)/255 end
    local low,high=math.min(table.unpack(rgb)),math.max(table.unpack(rgb))
    local span=high-low
    local result=""
    for i=1,3 do
        local ratio=span>0 and (rgb[i]-low)/span or 1
        local value=brightness*(1-saturation+saturation*ratio)
        result=result .. string.format("%02X",math.floor(math.max(0,math.min(1,value))*255+0.5))
    end
    return linear(result,1)
end
local function brush(widget, color)
    local ok = pcall(function() widget:SetBrushColor(color) end)
    if not ok then widget:SetBrushColor(FLinearColor(color.R,color.G,color.B,color.A)) end
end
local function textColor(widget, color)
    local ok = pcall(function() widget:SetColorAndOpacity({SpecifiedColor=color,ColorUseRule=0}) end)
    if not ok then
        widget:SetColorAndOpacity({SpecifiedColor=FLinearColor(color.R,color.G,color.B,color.A),ColorUseRule=0})
    end
end
local function font(widget, hud, cfg, size, face)
    if cfg.INHERIT_HUD_FONT then
        local donor = try(function() return hud.CommandTriggerKey_Text end)
        if valid(donor) then widget:SetFont(donor.Font) end
    end
    -- Only the destination's owned font struct is modified.
    local owned = widget.Font
    owned.Size = size
    if face and face ~= "" then owned.TypefaceFontName = fname(face) end
    widget:SetFont(owned)
end
function M.attach(hud, cfg, log, schedule)
    if not valid(hud) then return nil, "HUD invalid" end
    -- Wait until the character HUD has initialized its local player context.
    if not valid(try(function() return hud.CanvasPanel_Root end)) then
        return nil, "CanvasPanel_Root not ready"
    end
    local controller = try(function() return hud:GetOwningPlayer() end)
    local world = try(function() return hud:GetWorld() end)
    if not valid(controller) or not valid(world)
        or try(function() return controller:IsLocalController() end) ~= true then
        return nil, "local player/world not ready"
    end
    local container, viewport
    local ok, result = pcall(function()
        -- Unreal's factory initializes the widget and its owning player. Keep the
        -- alert outside the game's HUD so death cannot hide it with that parent.
        local library = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        local class = StaticFindObject("/Script/UMG.UserWidget")
        assert(valid(library) and valid(class), "viewport widget factory unavailable")
        -- A script reload can leave the previous version's viewport widget alive.
        -- Identify only our named root; never remove another mod's widget.
        local existing = try(function() return FindAllOf("UserWidget") end) or {}
        for _, widget in ipairs(existing) do
            local oldRoot = valid(widget) and try(function() return widget.WidgetTree.RootWidget end)
            local oldName = valid(oldRoot) and try(function() return oldRoot:GetFName():ToString() end)
            if type(oldName) == "string" and oldName:sub(1, #PREFIX) == PREFIX then
                widget:RemoveFromParent()
            end
        end
        viewport = library:Create(controller, class, controller)
        assert(valid(viewport), "viewport widget creation failed")
        local tree = viewport.WidgetTree
        if not valid(tree) then tree = construct("WidgetTree", viewport); viewport.WidgetTree = tree end
        local root = construct("Overlay", tree, true)
        tree.RootWidget = root
        viewport.bIsFocusable = false
        viewport:SetVisibility(3) -- Never captures mouse clicks or menu focus.
        container = construct("ScaleBox", tree, true)
        container:SetVisibility(1)
        container.Stretch = 7
        container:SetUserSpecifiedScale(cfg.SCALE)
        local width = construct("SizeBox", tree)
        width:SetWidthOverride(cfg.WIDTH)
        local content = construct("VerticalBox", tree)
        local function smallFont(label, size, face)
            local info = label.Font -- pristine UMG defaults, never HUD donor
            local candidate = try(function() return StaticFindObject(cfg.SMALL_FONT_PATH) end)
            if valid(candidate) then
                info.FontObject = candidate
                if cfg.VERBOSE or cfg.FONT_PROBE then
                    log("small text font selected configured asset: " .. cfg.SMALL_FONT_PATH)
                end
            else
                log("small text font configured asset unavailable; using pristine UMG default (not yet verified plain)")
            end
            info.Size = size
            info.TypefaceFontName = fname(face or cfg.SMALL_FONT_FACE)
            local tracked, err = pcall(function() info.LetterSpacing = cfg.SMALL_FONT_TRACKING end)
            if not tracked then log("small text font tracking unsupported: " .. tostring(err)) end
            label:SetFont(info)
            if cfg.VERBOSE or cfg.FONT_PROBE then
                local actual = try(function() return label.Font.FontObject end)
                if valid(actual) then
                    log("small text font readback: " .. tostring(try(function() return actual:GetFName():ToString() end)))
                else log("small text font readback: composite/default font, identity unavailable") end
            end
            label:SetAutoWrapText(true)
            textColor(label, linear(cfg.CONTEXT_COLOR))
        end
        local headline, context = construct("TextBlock", tree), construct("TextBlock", tree)
        font(headline, hud, cfg, cfg.HEADLINE_SIZE, cfg.FONT_HEADLINE_FACE)
        smallFont(context, cfg.CONTEXT_SIZE)
        textColor(headline, linear(cfg.HEADLINE_COLOR))
        textColor(context, linear(cfg.CONTEXT_COLOR))
        headline:SetAutoWrapText(true)
        context:SetAutoWrapText(true)
        local headlineSlot = assert(content:AddChildToVerticalBox(headline), "headline slot failed")
        headlineSlot:SetVerticalAlignment(1)
        -- Separate layout rows reserve real space; avoid a brush sitting on the
        -- text baseline or relying on padding around a one-unit desired height.
        local function spacer(height)
            local space=construct("SizeBox",tree)
            space:SetHeightOverride(height)
            assert(content:AddChildToVerticalBox(space))
        end
        spacer(cfg.DIVIDER_TOP_GAP)
        local divider = construct("SizeBox", tree)
        divider:SetWidthOverride(cfg.DIVIDER_WIDTH)
        divider:SetHeightOverride(1)
        local rule = construct("Border", tree)
        rule:SetPadding({Left=0,Right=0,Top=0,Bottom=0})
        brush(rule, linear(cfg.CONTEXT_COLOR, cfg.DIVIDER_OPACITY))
        assert(divider:AddChild(rule))
        local dividerSlot = assert(content:AddChildToVerticalBox(divider))
        dividerSlot:SetHorizontalAlignment(2)
        dividerSlot:SetVerticalAlignment(1)
        spacer(cfg.DIVIDER_BOTTOM_GAP)
        local contextSlot = assert(content:AddChildToVerticalBox(context), "context slot failed")
        contextSlot:SetPadding({Left=0,Right=0,Top=cfg.CONTEXT_GAP,Bottom=0})
        local controls = construct("HorizontalBox", tree)
        local controlsSlot = assert(content:AddChildToVerticalBox(controls))
        controlsSlot:SetHorizontalAlignment(2)
        controlsSlot:SetPadding({Left=0,Right=0,Top=8,Bottom=0})
        local keyLabels = {}
        local function keyGroup(labelText, withProgress)
            local group = construct("SizeBox", tree)
            group:SetWidthOverride(cfg.KEY_GROUP_WIDTH)
            local column = construct("VerticalBox", tree)
            assert(group:AddChild(column))
            assert(controls:AddChildToHorizontalBox(group))
            local tile = construct("SizeBox", tree)
            tile:SetWidthOverride(cfg.KEY_TILE_SIZE)
            tile:SetHeightOverride(cfg.KEY_TILE_SIZE)
            local layers = construct("Overlay", tree)
            layers:SetClipping(1) -- ClipToBounds
            assert(tile:AddChild(layers))
            local tileSlot=assert(column:AddChildToVerticalBox(tile))
            tileSlot:SetHorizontalAlignment(2)
            local backing=construct("Border",tree)
            backing:SetPadding({Left=0,Right=0,Top=0,Bottom=0})
            brush(backing,linear(cfg.KEY_EMPTY_COLOR,1))
            local backingSlot=assert(layers:AddChildToOverlay(backing))
            backingSlot:SetHorizontalAlignment(0); backingSlot:SetVerticalAlignment(0)
            local fill,fillBox
            if withProgress then
                fillBox=construct("SizeBox",tree)
                fillBox:SetWidthOverride(0)
                -- Stretch to the tile's arranged inner height rather than fixing
                -- a desired height that can leave a strip above the bottom edge.
                fillBox:SetClipping(1)
                fill=construct("Border",tree)
                fill:SetPadding({Left=0,Right=0,Top=0,Bottom=0})
                fill:SetRenderOpacity(cfg.KEY_FILL_OPACITY)
                assert(fillBox:AddChild(fill))
                fillBox:SetVisibility(1)
                local slot=assert(layers:AddChildToOverlay(fillBox))
                slot:SetHorizontalAlignment(1); slot:SetVerticalAlignment(0)
                slot:SetPadding({Left=TILE_BORDER,Right=TILE_BORDER,Top=TILE_BORDER,Bottom=TILE_BORDER})
            end
            -- Dark three-unit edge under each light one-unit edge provides
            -- local contrast on pale/red scenes without an alert-wide panel.
            for _,edge in ipairs({{0,1,true},{0,3,true},{1,0,false},{3,0,false}}) do
                local size=construct("SizeBox",tree)
                if edge[3] then size:SetHeightOverride(TILE_BORDER) else size:SetWidthOverride(TILE_BORDER) end
                local stroke=construct("Border",tree)
                stroke:SetPadding({Left=0,Right=0,Top=0,Bottom=0})
                brush(stroke,linear(cfg.TEXT_OUTLINE_COLOR,1))
                assert(size:AddChild(stroke))
                local slot=assert(layers:AddChildToOverlay(size))
                slot:SetHorizontalAlignment(edge[1]); slot:SetVerticalAlignment(edge[2])
            end
            -- Four one-unit strokes form an empty square without an opaque panel.
            for _,edge in ipairs({{0,1,true},{0,3,true},{1,0,false},{3,0,false}}) do
                local size=construct("SizeBox",tree)
                if edge[3] then size:SetHeightOverride(1) else size:SetWidthOverride(1) end
                local stroke=construct("Border",tree)
                stroke:SetPadding({Left=0,Right=0,Top=0,Bottom=0})
                brush(stroke,linear(cfg.CONTEXT_COLOR,cfg.KEY_OUTLINE_OPACITY))
                assert(size:AddChild(stroke))
                local slot=assert(layers:AddChildToOverlay(size))
                slot:SetHorizontalAlignment(edge[1]); slot:SetVerticalAlignment(edge[2])
            end
            local glyph=construct("TextBlock",tree)
            smallFont(glyph,cfg.KEY_GLYPH_SIZE,"Bold")
            glyph:SetText(FText(cfg.ACTION_KEY))
            local glyphSlot=assert(layers:AddChildToOverlay(glyph))
            glyphSlot:SetHorizontalAlignment(2); glyphSlot:SetVerticalAlignment(2)
            local label=construct("TextBlock",tree)
            smallFont(label,cfg.KEY_LABEL_SIZE)
            label:SetAutoWrapText(false)
            label:SetText(FText(labelText))
            local labelSlot=assert(column:AddChildToVerticalBox(label))
            labelSlot:SetPadding({Left=0,Right=0,Top=4,Bottom=0})
            keyLabels[#keyLabels+1]=glyph; keyLabels[#keyLabels+1]=label
            return group,fill,fillBox
        end
        local dismissGroup=keyGroup("DISMISS",false)
        local restartGroup,progress,progressBox=keyGroup("HOLD TO RESTART",true)
        -- Optional alphabet specimens use exactly the real small-text font settings.
        local specimenHint, specimenContext = construct("TextBlock", tree), construct("TextBlock", tree)
        smallFont(specimenHint, cfg.CONTROL_SIZE)
        smallFont(specimenContext, cfg.CONTEXT_SIZE)
        assert(content:AddChildToVerticalBox(specimenHint), "font specimen slot failed")
        assert(content:AddChildToVerticalBox(specimenContext), "font specimen slot failed")
        specimenHint:SetVisibility(1)
        specimenContext:SetVisibility(1)
        for _, label in ipairs({headline, context, specimenHint, specimenContext, table.unpack(keyLabels)}) do
            local info=label.Font
            local ok,err=pcall(function()
                local outline=info.OutlineSettings
                outline.OutlineSize=cfg.TEXT_OUTLINE_SIZE
                outline.OutlineColor=linear(cfg.TEXT_OUTLINE_COLOR,1)
                outline.bSeparateFillAlpha=false
                label:SetFont(info)
            end)
            if not ok then log("text outline unavailable; strong shadow only: " .. tostring(err)) end
            label:SetJustification(1)
            label:SetShadowOffset({X=cfg.SHADOW_OFFSET,Y=cfg.SHADOW_OFFSET})
            label:SetShadowColorAndOpacity({R=0,G=0,B=0,A=cfg.SHADOW_OPACITY})
        end
        assert(width:AddChild(content), "width parent failed")
        assert(container:AddChild(width), "scale parent failed")
        local slot = assert(root:AddChildToOverlay(container), "HUD overlay slot failed")
        local anchor = ANCHORS[cfg.ANCHOR] or ANCHORS.TopRight
        slot:SetHorizontalAlignment(anchor[1])
        slot:SetVerticalAlignment(anchor[2])
        slot:SetPadding({Left=cfg.MARGIN,Right=cfg.MARGIN,Top=cfg.MARGIN,Bottom=cfg.MARGIN})
        if cfg.ANCHOR == "AboveCrosshair" then
            container:SetRenderTranslation({X=0,Y=-(cfg.CENTER_OFFSET or 140)})
        end

        local handle = {hud=hud,viewport=viewport,world=world,controller=controller,container=container,headline=headline,context=context,
            controls=controls,specimenHint=specimenHint,specimenContext=specimenContext,progress=progress,progressBox=progressBox,restartGroup=restartGroup,soundWarned=false,animation=0}
        function handle:isValid()
            local controllerWorld = valid(self.controller) and try(function() return self.controller:GetWorld() end)
            return valid(self.viewport) and valid(self.world) and valid(controllerWorld)
                and controllerWorld:GetAddress() == self.world:GetAddress()
                and valid(self.container) and valid(self.headline)
                and valid(self.context) and valid(self.controls) and valid(self.specimenHint) and valid(self.specimenContext) and valid(self.progress) and valid(self.progressBox) and valid(self.restartGroup)
        end
        function handle:setHoldProgress(value)
            local visible = cfg.SHOW_HOLD_PROGRESS and type(value)=="number"
            local amount=visible and math.max(0,math.min(1,value)) or 0
            self.progressBox:SetWidthOverride(math.max(0,cfg.KEY_TILE_SIZE-2*TILE_BORDER)*amount)
            self.progressBox:SetVisibility(amount>0 and 3 or 1)
        end
        function handle:hide()
            self.animation = self.animation + 1
            if valid(self.progress) and valid(self.restartGroup) then self:setHoldProgress(nil) end
            if valid(self.container) then self.container:SetVisibility(1) end
        end
        function handle:destroy()
            self:hide()
            if valid(self.container) then self.container:RemoveFromParent() end
            if valid(self.viewport) then self.viewport:RemoveFromParent() end
        end
        function handle:ensureViewport()
            -- Restore only our overlay if a death transition removes viewport UI.
            -- A different/invalid world ends its lifetime instead of restoring it.
            if self:isValid() and not self.viewport:IsInViewport() then self.viewport:AddToViewport(100) end
        end
        function handle:show(message, refresh)
            self.animation = self.animation + 1
            local generation = self.animation
            self.headline:SetText(FText((message.severity == "critical" and "INCIDENT: " or message.severity == "warning" and "WARNING: " or "STATUS: ") .. string.upper(message.headline)))
            self.context:SetText(FText(message.context or ""))
            self.context:SetVisibility(message.context and message.context ~= "" and 3 or 1)
            self.controls:SetVisibility(3)
            self.restartGroup:SetVisibility(message.restartAvailable and 3 or 1)
            self.specimenHint:SetVisibility(message.fontProbe and 3 or 1)
            self.specimenContext:SetVisibility(message.fontProbe and 3 or 1)
            if message.fontProbe then
                self.controls:SetVisibility(1)
                self.context:SetVisibility(1)
                self.specimenHint:SetText(FText(tostring(cfg.CONTROL_SIZE) .. "pt Regular: a o e c s\nabcdefghijklmnopqrstuvwxyz\naoa aao ooa ace cases"))
                self.specimenContext:SetText(FText(tostring(cfg.CONTEXT_SIZE) .. "pt Regular: a o e c s\nabcdefghijklmnopqrstuvwxyz"))
            end
            local color = message.severity == "critical" and cfg.CRITICAL_COLOR
                or message.severity == "warning" and cfg.WARNING_COLOR or cfg.INFO_COLOR
            textColor(self.headline, linear(color))
            brush(self.progress,vivid(color, cfg.KEY_FILL_SATURATION, cfg.KEY_FILL_BRIGHTNESS))
            self.container:SetRenderOpacity(not refresh and cfg.FADE_IN_MS > 0 and 0 or 1)
            self.container:SetVisibility(3)
            local function opacityAfter(delay, opacity)
                schedule(math.floor(delay + 0.5), function()
                    if self.animation ~= generation or not self:isValid() then return end
                    self.container:SetRenderOpacity(opacity)
                end)
            end
            -- All steps use the existing scheduler, and only exist while a
            -- toast is fading. Old callbacks are inert after hide/new show.
            if not refresh and cfg.FADE_IN_MS > 0 then
                local steps = math.ceil(cfg.FADE_IN_MS / cfg.ANIMATION_STEP_MS)
                for i=1,steps do opacityAfter(cfg.FADE_IN_MS*i/steps, i/steps) end
            end
            if not message.persistent and cfg.FADE_OUT_MS > 0 then
                local steps = math.ceil(cfg.FADE_OUT_MS / cfg.ANIMATION_STEP_MS)
                local start = cfg.ALERT_MS - cfg.FADE_OUT_MS
                for i=1,steps do opacityAfter(start+cfg.FADE_OUT_MS*i/steps, 1-i/steps) end
            end
        end
        function handle:playSound()
            if not cfg.SOUND then return end
            local sound = cfg.SOUND_PATH ~= "" and try(function() return StaticFindObject(cfg.SOUND_PATH) end)
            local played = valid(sound) and pcall(function() self.viewport:PlaySound(sound) end)
            if not played and not self.soundWarned then
                self.soundWarned = true
                log("optional sound unavailable; visual alerts continue")
            end
        end
        handle:ensureViewport()
        log("independent viewport overlay attached; survives character HUD removal")
        return handle
    end)
    if ok then return result end
    if valid(container) then pcall(function() container:RemoveFromParent() end) end
    if valid(viewport) then pcall(function() viewport:RemoveFromParent() end) end
    return nil, tostring(result)
end
return M
