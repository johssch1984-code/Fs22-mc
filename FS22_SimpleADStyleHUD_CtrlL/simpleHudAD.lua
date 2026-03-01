-- simpleHudAD.lua v1.0.3.1
-- Button click uses Mission00:mouseEvent (reliable).
-- Adds Cut/Fill output.

source(g_currentModDirectory .. "scripts/HudTextUpdater.lua")

SimpleHudAD = {
    isVisible = false,
    actionEventId = nil,
    firedOnce = false,
    lastRawDown = false,

    dynamicText = "E=---  N=---  H=---",
    cutFillText = "Cut/Fill: ---",
    debugLine = "Lock: none",

    bgOv = nil,
    headerOv = nil,
    lineOv = nil,
    btnOv = nil,

    btnX = 0,
    btnY = 0,
    btnW = 0,
    btnH = 0,

    mouseX = nil,
    mouseY = nil,
    mouseDown = false,
    lastMouseDown = false
}

SimpleHudAD.colBg = {0.05, 0.05, 0.05, 0.72}
SimpleHudAD.colHeader = {0.10, 0.55, 0.95, 0.95}
SimpleHudAD.colLine = {0.10, 0.55, 0.95, 0.95}
SimpleHudAD.colBtn = {0.15, 0.15, 0.15, 0.90}
SimpleHudAD.colBtnHover = {0.25, 0.25, 0.25, 0.95}

local PIXEL = "dataS/scripts/shared/graph_pixel.dds"

function SimpleHudAD:createOverlays()
    if self.bgOv == nil then self.bgOv = Overlay.new(PIXEL, 0, 0, 1, 1) end
    if self.headerOv == nil then self.headerOv = Overlay.new(PIXEL, 0, 0, 1, 1) end
    if self.lineOv == nil then self.lineOv = Overlay.new(PIXEL, 0, 0, 1, 1) end
    if self.btnOv == nil then self.btnOv = Overlay.new(PIXEL, 0, 0, 1, 1) end
end

function SimpleHudAD:deleteOverlays()
    if self.bgOv ~= nil then self.bgOv:delete(); self.bgOv = nil end
    if self.headerOv ~= nil then self.headerOv:delete(); self.headerOv = nil end
    if self.lineOv ~= nil then self.lineOv:delete(); self.lineOv = nil end
    if self.btnOv ~= nil then self.btnOv:delete(); self.btnOv = nil end
end

local function box(ov, x, y, w, h, c)
    ov:setPosition(x, y)
    ov:setDimension(w, h)
    ov:setColor(c[1], c[2], c[3], c[4])
    ov:render()
end

local function txt(x, y, size, t, align, bold)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(align or RenderText.ALIGN_LEFT)
    setTextBold(bold == true)
    renderText(x, y, size, t)
end

local function inside(mx, my, x, y, w, h)
    return mx ~= nil and my ~= nil and mx >= x and mx <= (x + w) and my >= y and my <= (y + h)
end

function SimpleHudAD:onMouseEvent(posX, posY, isDown, isUp, button)
    self.mouseX = posX
    self.mouseY = posY
    if button == Input.MOUSE_BUTTON_LEFT then
        if isDown then
            self.mouseDown = true
        elseif isUp then
            self.mouseDown = false
        end
    end
end

function SimpleHudAD:onAction(_, inputValue, callbackState, _)
    self.firedOnce = true
    if callbackState == 1 or inputValue == 1 then
        self.isVisible = not self.isVisible
    end
end

function SimpleHudAD:onMissionLoadMapFinished(mission)
    if mission == nil or mission.inputManager == nil then return end
    if self.actionEventId ~= nil then return end

    local actionId = InputAction.TOGGLE_SIMPLE_HUD or InputAction["TOGGLE_SIMPLE_HUD"]
    if actionId == nil then return end

    local _, eventId = mission.inputManager:registerActionEvent(actionId, self, self.onAction, false, true, false, true)
    self.actionEventId = eventId
end

local function rawCtrlLDown()
    return Input.isKeyPressed(Input.KEY_l)
        and (Input.isKeyPressed(Input.KEY_lctrl) or Input.isKeyPressed(Input.KEY_rctrl))
end

function SimpleHudAD:onMissionUpdate(mission, dt)
    HudTextUpdater.updateText(self, mission)

    if not self.firedOnce then
        local d = rawCtrlLDown()
        if d and not self.lastRawDown then
            self.isVisible = not self.isVisible
        end
        self.lastRawDown = d
    end

    if self.isVisible then
        local down = self.mouseDown
        if down and not self.lastMouseDown then
            if inside(self.mouseX, self.mouseY, self.btnX, self.btnY, self.btnW, self.btnH) then
                HudTextUpdater.setDatumToCurrent()
            end
        end
        self.lastMouseDown = down
    else
        self.lastMouseDown = false
    end
end

function SimpleHudAD:onMissionDelete(mission)
    self.actionEventId = nil
    self.firedOnce = false
    self.lastRawDown = false
    self.lastMouseDown = false
    self.isVisible = false
    self.dynamicText = "E=---  N=---  H=---"
    self.cutFillText = "Cut/Fill: ---"
    self.debugLine = "Lock: none"
    self:deleteOverlays()
end

function SimpleHudAD:onMissionDraw(mission)
    if not self.isVisible then return end
    self:createOverlays()

    local w, h = getNormalizedScreenValues(1080, 175)
    local marginX, marginY = getNormalizedScreenValues(18, 18)

    local offX = g_safeFrameOffsetX or 0
    local offY = g_safeFrameOffsetY or 0

    local x = 1 - offX - marginX - w
    local y = offY + marginY

    box(self.bgOv, x, y, w, h, self.colBg)

    local _, headerH = getNormalizedScreenValues(0, 24)
    box(self.headerOv, x, y + h - headerH, w, headerH, self.colHeader)

    local _, lineH = getNormalizedScreenValues(0, 2)
    box(self.lineOv, x, y, w, lineH, self.colLine)

    local padX, _ = getNormalizedScreenValues(12, 0)
    local _, rowSize = getNormalizedScreenValues(0, 14)
    local _, titleSize = getNormalizedScreenValues(0, 16)
    local _, headerOff = getNormalizedScreenValues(0, 4)
    local _, gap = getNormalizedScreenValues(0, 18)

    txt(x + padX, y + h - headerH + headerOff, titleSize, "Survey HUD", RenderText.ALIGN_LEFT, true)

    local row1 = y + h - headerH - 0.03
    local row2 = row1 - gap
    local row3 = row2 - gap

    txt(x + padX, row1, rowSize, self.dynamicText, RenderText.ALIGN_LEFT, false)
    txt(x + padX, row2, rowSize, self.cutFillText, RenderText.ALIGN_LEFT, false)
    txt(x + padX, row3, rowSize, self.debugLine, RenderText.ALIGN_LEFT, false)

    local btnW, btnH = getNormalizedScreenValues(90, 26)
    local btnX = x + w - padX - btnW
    local btnY = y + h - headerH + 0.002

    self.btnX, self.btnY, self.btnW, self.btnH = btnX, btnY, btnW, btnH

    local hover = inside(self.mouseX, self.mouseY, btnX, btnY, btnW, btnH)
    box(self.btnOv, btnX, btnY, btnW, btnH, hover and self.colBtnHover or self.colBtn)

    local _, btnTextSize = getNormalizedScreenValues(0, 14)
    txt(btnX + 0.006, btnY + 0.006, btnTextSize, "Set 0", RenderText.ALIGN_LEFT, true)
end

Mission00.loadMapFinished = Utils.appendedFunction(Mission00.loadMapFinished, function(mission)
    SimpleHudAD:onMissionLoadMapFinished(mission)
end)
Mission00.update = Utils.appendedFunction(Mission00.update, function(mission, dt)
    SimpleHudAD:onMissionUpdate(mission, dt)
end)
Mission00.draw = Utils.appendedFunction(Mission00.draw, function(mission)
    SimpleHudAD:onMissionDraw(mission)
end)
Mission00.delete = Utils.appendedFunction(Mission00.delete, function(mission)
    SimpleHudAD:onMissionDelete(mission)
end)
Mission00.mouseEvent = Utils.appendedFunction(Mission00.mouseEvent, function(mission, posX, posY, isDown, isUp, button)
    SimpleHudAD:onMouseEvent(posX, posY, isDown, isUp, button)
end)
