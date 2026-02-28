-- simpleHudAD.lua v1.0.2.2
-- Survey/Datum HUD
-- Lock to bucket toolpoint ONLY while inside a vehicle; release on TAB switch or exit.

source(g_currentModDirectory .. "scripts/HudTextUpdater.lua")

SimpleHudAD = {
    isVisible = false,
    actionEventId = nil,
    firedOnce = false,
    lastRawDown = false,
    dynamicText = "E=---  N=---  H=---",
    debugLine = "Lock: none",
    bgOv = nil,
    headerOv = nil,
    lineOv = nil
}

SimpleHudAD.colBg = {0.05, 0.05, 0.05, 0.72}
SimpleHudAD.colHeader = {0.10, 0.55, 0.95, 0.95}
SimpleHudAD.colLine = {0.10, 0.55, 0.95, 0.95}

local PIXEL = "dataS/scripts/shared/graph_pixel.dds"

function SimpleHudAD:createOverlays()
    if self.bgOv == nil then self.bgOv = Overlay.new(PIXEL, 0, 0, 1, 1) end
    if self.headerOv == nil then self.headerOv = Overlay.new(PIXEL, 0, 0, 1, 1) end
    if self.lineOv == nil then self.lineOv = Overlay.new(PIXEL, 0, 0, 1, 1) end
end

function SimpleHudAD:deleteOverlays()
    if self.bgOv ~= nil then self.bgOv:delete(); self.bgOv = nil end
    if self.headerOv ~= nil then self.headerOv:delete(); self.headerOv = nil end
    if self.lineOv ~= nil then self.lineOv:delete(); self.lineOv = nil end
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
end

function SimpleHudAD:onMissionDelete(mission)
    self.actionEventId = nil
    self.firedOnce = false
    self.lastRawDown = false
    self.isVisible = false
    self.dynamicText = "E=---  N=---  H=---"
    self.debugLine = "Lock: none"
    self:deleteOverlays()
end

function SimpleHudAD:onMissionDraw(mission)
    if not self.isVisible then return end
    self:createOverlays()

    local w, h = getNormalizedScreenValues(820, 130)
    local marginX, marginY = getNormalizedScreenValues(18, 18)

    local offX = g_safeFrameOffsetX or 0
    local offY = g_safeFrameOffsetY or 0

    local x = 1 - offX - marginX - w
    local y = offY + marginY

    box(self.bgOv, x, y, w, h, self.colBg)

    local _, headerH = getNormalizedScreenValues(0, 22)
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

    txt(x + padX, row1, rowSize, self.dynamicText, RenderText.ALIGN_LEFT, false)
    txt(x + padX, row2, rowSize, self.debugLine, RenderText.ALIGN_LEFT, false)
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
