-- Simple AD-style HUD (CTRL+L)
-- v1.0.1.1
-- Overlay drawing + Mission00 input + raw fallback.
-- Dynamic text updated each tick, using groundReferenceNode if present.

source(g_currentModDirectory .. "scripts/DistanceToPlane.lua")
source(g_currentModDirectory .. "scripts/HudTextUpdater.lua")

SimpleHudAD = {
    isVisible = false,
    actionEventId = nil,
    firedOnce = false,
    lastRawDown = false,
    debug = true,

    dynamicText = "Distance: n/a",

    bgOv = nil,
    headerOv = nil,
    lineOv = nil
}

SimpleHudAD.colBg     = {0.05, 0.05, 0.05, 0.72}
SimpleHudAD.colHeader = {0.10, 0.55, 0.95, 0.95}
SimpleHudAD.colText   = {1.00, 1.00, 1.00, 1.00}
SimpleHudAD.colMuted  = {0.85, 0.88, 0.92, 0.90}

local function dbg(msg)
    if SimpleHudAD.debug then
        print("[SimpleHudAD] " .. msg)
    end
end

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

local function renderBox(ov, x, y, w, h, c)
    ov:setPosition(x, y)
    ov:setDimension(w, h)
    ov:setColor(c[1], c[2], c[3], c[4])
    ov:render()
end

local function renderTextLine(x, y, size, text, c, align, bold)
    setTextColor(c[1], c[2], c[3], c[4])
    setTextAlignment(align or RenderText.ALIGN_LEFT)
    setTextBold(bold == true)
    renderText(x, y, size, text)
end

function SimpleHudAD:onAction(actionName, inputValue, callbackState, isAnalog)
    self.firedOnce = true
    dbg(string.format("FIRED actionName=%s inputValue=%s callbackState=%s",
        tostring(actionName), tostring(inputValue), tostring(callbackState)))

    if callbackState == 1 or inputValue == 1 then
        self.isVisible = not self.isVisible
        dbg("toggle -> " .. tostring(self.isVisible) .. " (via action event)")
    end
end

function SimpleHudAD:onMissionLoadMapFinished(mission)
    if mission == nil or mission.inputManager == nil then
        dbg("ERROR: mission/inputManager not ready in loadMapFinished")
        return
    end
    if self.actionEventId ~= nil then return end

    local actionId = InputAction.TOGGLE_SIMPLE_HUD
    if actionId == nil then actionId = InputAction["TOGGLE_SIMPLE_HUD"] end
    if actionId == nil then
        dbg("ERROR: InputAction TOGGLE_SIMPLE_HUD is nil")
        return
    end

    local _, eventId = mission.inputManager:registerActionEvent(
        actionId, self, self.onAction,
        false, true, false, true
    )
    self.actionEventId = eventId

    if self.actionEventId ~= nil then
        mission.inputManager:setActionEventTextVisibility(self.actionEventId, true)
        mission.inputManager:setActionEventText(self.actionEventId, g_i18n:getText("input_TOGGLE_SIMPLE_HUD"))
        mission.inputManager:setActionEventActive(self.actionEventId, true)
    end

    dbg(string.format("registered actionEventId=%s actionId=%s", tostring(self.actionEventId), tostring(actionId)))
end

function SimpleHudAD:onMissionDelete(mission)
    if self.actionEventId ~= nil and mission ~= nil and mission.inputManager ~= nil then
        mission.inputManager:removeActionEvent(self.actionEventId)
        dbg("removed action event")
    end
    self.actionEventId = nil
    self.firedOnce = false
    self.lastRawDown = false
    self.isVisible = false
    self.dynamicText = "Distance: n/a"
    self:deleteOverlays()
end

local function isRawCtrlLDown()
    local lDown = Input.isKeyPressed(Input.KEY_l)
    local ctrlDown = Input.isKeyPressed(Input.KEY_lctrl) or Input.isKeyPressed(Input.KEY_rctrl)
    return lDown and ctrlDown
end

function SimpleHudAD:onMissionUpdate(mission, dt)
    HudTextUpdater.updateText(self, mission, dt)

    if not self.firedOnce then
        local rawDown = isRawCtrlLDown()
        if rawDown and not self.lastRawDown then
            self.isVisible = not self.isVisible
            dbg("toggle -> " .. tostring(self.isVisible) .. " (via RAW fallback)")
        end
        self.lastRawDown = rawDown
    end

    if self.actionEventId ~= nil and mission ~= nil and mission.inputManager ~= nil then
        mission.inputManager:setActionEventActive(self.actionEventId, true)
    end
end

function SimpleHudAD:onMissionDraw(mission)
    if not self.isVisible then return end

    self:createOverlays()

    local w, h = getNormalizedScreenValues(760, 140)
    local marginX, marginY = getNormalizedScreenValues(18, 18)

    local offX = g_safeFrameOffsetX or 0
    local offY = g_safeFrameOffsetY or 0

    local x = 1 - offX - marginX - w
    local y = offY + marginY

    renderBox(self.bgOv, x, y, w, h, self.colBg)

    local _, headerH = getNormalizedScreenValues(0, 24)
    renderBox(self.headerOv, x, y + h - headerH, w, headerH, self.colHeader)

    local _, lineH = getNormalizedScreenValues(0, 2)
    renderBox(self.lineOv, x, y, w, lineH, self.colHeader)

    local padX, _ = getNormalizedScreenValues(12, 0)
    local _, padY = getNormalizedScreenValues(0, 10)

    local _, titleSize = getNormalizedScreenValues(0, 16)
    local _, rowSize   = getNormalizedScreenValues(0, 14)
    local _, headerOffY = getNormalizedScreenValues(0, 4)
    local _, lineGap = getNormalizedScreenValues(0, 18)

    local headerY = y + h - headerH + headerOffY
    renderTextLine(x + padX, headerY, titleSize, "AutoDrive HUD", self.colText, RenderText.ALIGN_LEFT, true)
    renderTextLine(x + w - padX, headerY, titleSize, "ON", self.colText, RenderText.ALIGN_RIGHT, true)

    local row1Y = y + h - headerH - padY - lineGap
    local row2Y = row1Y - lineGap

    renderTextLine(x + padX, row1Y, rowSize, self.dynamicText, self.colText, RenderText.ALIGN_LEFT, false)

    renderTextLine(x + padX, row2Y, rowSize, "Shortcut:", self.colMuted, RenderText.ALIGN_LEFT, false)
    renderTextLine(x + w - padX, row2Y, rowSize, "CTRL + L", self.colText, RenderText.ALIGN_RIGHT, false)
end

Mission00.loadMapFinished = Utils.appendedFunction(Mission00.loadMapFinished, function(mission)
    SimpleHudAD:onMissionLoadMapFinished(mission)
end)

Mission00.delete = Utils.appendedFunction(Mission00.delete, function(mission)
    SimpleHudAD:onMissionDelete(mission)
end)

Mission00.update = Utils.appendedFunction(Mission00.update, function(mission, dt)
    SimpleHudAD:onMissionUpdate(mission, dt)
end)

Mission00.draw = Utils.appendedFunction(Mission00.draw, function(mission)
    SimpleHudAD:onMissionDraw(mission)
end)
