-- FS22 Survey HUD (CTRL+L)
-- v1.0.3.2
-- KEEP: Mission00 registration + raw CTRL+L fallback

SimpleHudAD = {
    isVisible = false,
    actionEventId = nil,
    actionEventIdSetZero = nil,

    firedOnce = false,       -- true if toggle action event callback ever fires
    lastRawDown = false,     -- debounce for raw polling (toggle)
    lastRawZeroDown = false, -- debounce for raw polling (set zero)

    debug = true,

    -- overlays (created lazily)
    bgOv = nil,
    headerOv = nil,
    lineOv = nil,
    cellOv = nil,

    -- survey data
    data = {
        n = nil,
        e = nil,
        h = nil,
        cutFill = nil
    },

    -- target height (set zero)
    zeroH = nil
}

-- Theme (AutoDrive-ish)
SimpleHudAD.colBg     = {0.05, 0.05, 0.05, 0.72}
SimpleHudAD.colHeader = {0.10, 0.55, 0.95, 0.95}
SimpleHudAD.colText   = {1.00, 1.00, 1.00, 1.00}
SimpleHudAD.colMuted  = {0.85, 0.88, 0.92, 0.90}
SimpleHudAD.colGood   = {0.20, 0.85, 0.35, 0.95}
SimpleHudAD.colWarn   = {0.95, 0.80, 0.15, 0.95}
SimpleHudAD.colBad    = {0.95, 0.25, 0.25, 0.95}
SimpleHudAD.colCellBg = {0.00, 0.00, 0.00, 0.25}

local function dbg(msg)
    if SimpleHudAD.debug then
        print("[SimpleHudAD] " .. msg)
    end
end

-- GIANTS ships a 1x1 pixel texture used by many mods for colored rectangles
local PIXEL = "dataS/scripts/shared/graph_pixel.dds"

function SimpleHudAD:createOverlays()
    if self.bgOv == nil then
        self.bgOv = Overlay.new(PIXEL, 0, 0, 1, 1)
    end
    if self.headerOv == nil then
        self.headerOv = Overlay.new(PIXEL, 0, 0, 1, 1)
    end
    if self.lineOv == nil then
        self.lineOv = Overlay.new(PIXEL, 0, 0, 1, 1)
    end
    if self.cellOv == nil then
        self.cellOv = Overlay.new(PIXEL, 0, 0, 1, 1)
    end
end

function SimpleHudAD:deleteOverlays()
    if self.bgOv ~= nil then self.bgOv:delete(); self.bgOv = nil end
    if self.headerOv ~= nil then self.headerOv:delete(); self.headerOv = nil end
    if self.lineOv ~= nil then self.lineOv:delete(); self.lineOv = nil end
    if self.cellOv ~= nil then self.cellOv:delete(); self.cellOv = nil end
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

local function fmtSigned(v, decimals)
    if v == nil then
        return "--"
    end

    decimals = decimals or 3
    local fmt = string.format("%%+.%df", decimals)
    return string.format(fmt, v)
end

local function getBandColor(self, v)
    if v == nil then
        return self.colMuted
    end

    local av = math.abs(v)
    if av <= 0.02 then
        return self.colGood
    elseif av <= 0.05 then
        return self.colWarn
    end

    return self.colBad
end

function SimpleHudAD:setSurveyData(n, e, h, cutFill)
    self.data.n = n
    self.data.e = e
    self.data.h = h
    self.data.cutFill = cutFill
end

local function getToolpointNode(mission)
    if mission ~= nil and mission.controlledVehicle ~= nil then
        local vehicle = mission.controlledVehicle
        if vehicle.rootNode ~= nil then
            return vehicle.rootNode
        end
    end

    if mission ~= nil and mission.player ~= nil and mission.player.rootNode ~= nil then
        return mission.player.rootNode
    end

    return nil
end

local function updateSurveyValues(self, mission)
    local node = getToolpointNode(mission)
    if node == nil then
        return
    end

    local x, y, z = getWorldTranslation(node)

    -- Display convention: N = Z, E = X, H = Y (meters)
    local n = z
    local e = x
    local h = y

    if self.zeroH == nil then
        self.zeroH = h
    end

    -- Positive => FILL needed, Negative => CUT needed
    local cutFill = self.zeroH - h
    self:setSurveyData(n, e, h, cutFill)
end

-- =========================
-- Action-event callbacks
-- =========================
function SimpleHudAD:onAction(actionName, inputValue, callbackState, isAnalog)
    self.firedOnce = true
    dbg(string.format("FIRED actionName=%s inputValue=%s callbackState=%s",
        tostring(actionName), tostring(inputValue), tostring(callbackState)))

    if callbackState == 1 or inputValue == 1 then
        self.isVisible = not self.isVisible
        dbg("toggle -> " .. tostring(self.isVisible) .. " (via action event)")
    end
end

function SimpleHudAD:onActionSetZero(actionName, inputValue, callbackState, isAnalog)
    if callbackState == 1 or inputValue == 1 then
        local node = getToolpointNode(g_currentMission)
        if node ~= nil then
            local _, y, _ = getWorldTranslation(node)
            self.zeroH = y
            dbg("set zero -> " .. tostring(self.zeroH))
        end
    end
end

-- =========================
-- Mission00 hook points
-- =========================
function SimpleHudAD:onMissionLoadMapFinished(mission)
    if mission == nil or mission.inputManager == nil then
        dbg("ERROR: mission/inputManager not ready in loadMapFinished")
        return
    end

    -- Toggle HUD
    if self.actionEventId == nil then
        local actionId = InputAction.TOGGLE_SIMPLE_HUD
        if actionId == nil then
            actionId = InputAction["TOGGLE_SIMPLE_HUD"]
        end

        if actionId == nil then
            dbg("ERROR: InputAction TOGGLE_SIMPLE_HUD is nil")
        else
            local _, eventId = mission.inputManager:registerActionEvent(
                actionId,
                self,
                self.onAction,
                false,  -- triggerUp
                true,   -- triggerDown
                false,  -- triggerAlways
                true    -- startActive
            )
            self.actionEventId = eventId

            if self.actionEventId ~= nil then
                mission.inputManager:setActionEventTextVisibility(self.actionEventId, true)
                mission.inputManager:setActionEventText(self.actionEventId, g_i18n:getText("input_TOGGLE_SIMPLE_HUD"))
                mission.inputManager:setActionEventActive(self.actionEventId, true)
            end

            dbg(string.format("registered TOGGLE, actionEventId=%s actionId=%s",
                tostring(self.actionEventId), tostring(actionId)))
        end
    end

    -- Set zero
    if self.actionEventIdSetZero == nil then
        local actionId = InputAction.SURVEY_SET_ZERO
        if actionId == nil then
            actionId = InputAction["SURVEY_SET_ZERO"]
        end

        if actionId == nil then
            dbg("ERROR: InputAction SURVEY_SET_ZERO is nil")
        else
            local _, eventId = mission.inputManager:registerActionEvent(
                actionId,
                self,
                self.onActionSetZero,
                false,
                true,
                false,
                true
            )
            self.actionEventIdSetZero = eventId

            if self.actionEventIdSetZero ~= nil then
                mission.inputManager:setActionEventTextVisibility(self.actionEventIdSetZero, true)
                mission.inputManager:setActionEventText(self.actionEventIdSetZero, g_i18n:getText("input_SURVEY_SET_ZERO"))
                mission.inputManager:setActionEventActive(self.actionEventIdSetZero, true)
            end

            dbg(string.format("registered SET_ZERO, actionEventId=%s actionId=%s",
                tostring(self.actionEventIdSetZero), tostring(actionId)))
        end
    end
end

function SimpleHudAD:onMissionDelete(mission)
    if mission ~= nil and mission.inputManager ~= nil then
        if self.actionEventId ~= nil then
            mission.inputManager:removeActionEvent(self.actionEventId)
            dbg("removed TOGGLE action event")
        end
        if self.actionEventIdSetZero ~= nil then
            mission.inputManager:removeActionEvent(self.actionEventIdSetZero)
            dbg("removed SET_ZERO action event")
        end
    end

    self.actionEventId = nil
    self.actionEventIdSetZero = nil
    self.firedOnce = false
    self.lastRawDown = false
    self.lastRawZeroDown = false
    self.isVisible = false
    self.zeroH = nil

    self:deleteOverlays()
end

-- =========================
-- HARD fallback: raw key polling
-- =========================
local function isRawCtrlLDown()
    local lDown = Input.isKeyPressed(Input.KEY_l)
    local ctrlDown = Input.isKeyPressed(Input.KEY_lctrl) or Input.isKeyPressed(Input.KEY_rctrl)
    return lDown and ctrlDown
end

local function isRawCtrl0Down()
    local zeroDown = Input.isKeyPressed(Input.KEY_0)
    local ctrlDown = Input.isKeyPressed(Input.KEY_lctrl) or Input.isKeyPressed(Input.KEY_rctrl)
    return zeroDown and ctrlDown
end

function SimpleHudAD:onMissionUpdate(mission, dt)
    -- update values always (so HUD never shows '--')
    updateSurveyValues(self, mission)

    -- toggle HUD: action event or raw fallback
    if not self.firedOnce then
        local rawDown = isRawCtrlLDown()
        if rawDown and not self.lastRawDown then
            self.isVisible = not self.isVisible
            dbg("toggle -> " .. tostring(self.isVisible) .. " (via RAW fallback)")
        end
        self.lastRawDown = rawDown
    end

    -- raw fallback for set zero (always available)
    local rawZeroDown = isRawCtrl0Down()
    if rawZeroDown and not self.lastRawZeroDown then
        local node = getToolpointNode(mission)
        if node ~= nil then
            local _, y, _ = getWorldTranslation(node)
            self.zeroH = y
            dbg("set zero -> " .. tostring(self.zeroH) .. " (via RAW fallback)")
        end
    end
    self.lastRawZeroDown = rawZeroDown

    if mission ~= nil and mission.inputManager ~= nil then
        if self.actionEventId ~= nil then
            mission.inputManager:setActionEventActive(self.actionEventId, true)
        end
        if self.actionEventIdSetZero ~= nil then
            mission.inputManager:setActionEventActive(self.actionEventIdSetZero, true)
        end
    end
end

function SimpleHudAD:onMissionDraw(mission)
    if not self.isVisible then
        return
    end

    self:createOverlays()

    local w, h = getNormalizedScreenValues(480, 320)
    local marginX, marginY = getNormalizedScreenValues(18, 18)

    local offX = g_safeFrameOffsetX or 0
    local offY = g_safeFrameOffsetY or 0

    local x = 1 - offX - marginX - w
    local y = offY + marginY

    -- background + header + line using overlays (AutoDrive-style)
    renderBox(self.bgOv, x, y, w, h, self.colBg)

    local _, headerH = getNormalizedScreenValues(0, 32)
    renderBox(self.headerOv, x, y + h - headerH, w, headerH, self.colHeader)

    local _, lineH = getNormalizedScreenValues(0, 2)
    renderBox(self.lineOv, x, y, w, lineH, self.colHeader)

    -- text sizes
    local padX, _ = getNormalizedScreenValues(16, 0)
    local _, padY = getNormalizedScreenValues(0, 14)
    local _, titleSize = getNormalizedScreenValues(0, 20)
    local _, headSize  = getNormalizedScreenValues(0, 32)
    local _, valueSize = getNormalizedScreenValues(0, 24)
    local _, rowSize   = getNormalizedScreenValues(0, 16)
    local _, headerOffY = getNormalizedScreenValues(0, 6)

    local headerY = y + h - headerH + headerOffY

    renderTextLine(x + padX, headerY, titleSize, "Survey HUD", self.colText, RenderText.ALIGN_LEFT, true)
    renderTextLine(x + w - padX, headerY, titleSize, "CTRL + L", self.colText, RenderText.ALIGN_RIGHT, true)

    -- values
    local n = self.data.n
    local e = self.data.e
    local hVal = self.data.h
    local cutFill = self.data.cutFill

    -- headline: CUT / FILL
    local headlineY = y + h - headerH - padY - headSize
    local bandCol = getBandColor(self, cutFill)

    local direction = ""
    if cutFill ~= nil then
        if cutFill > 0 then
            direction = "^"
        elseif cutFill < 0 then
            direction = "v"
        end
    end

    local headlineText = "CUT/FILL"
    if cutFill ~= nil then
        if cutFill > 0 then
            headlineText = "FILL"
        elseif cutFill < 0 then
            headlineText = "CUT"
        else
            headlineText = "LEVEL"
        end
    end

    renderTextLine(x + padX, headlineY, headSize, headlineText, self.colText, RenderText.ALIGN_LEFT, true)
    renderTextLine(x + w - padX, headlineY, headSize, string.format("%s %s", direction, fmtSigned(cutFill, 3)), bandCol, RenderText.ALIGN_RIGHT, true)

    -- band indicator
    local _, bandH = getNormalizedScreenValues(0, 10)
    renderBox(self.lineOv, x + padX, headlineY - padY, w - padX - padX, bandH, bandCol)

    -- N / E / H table (3 columns)
    local _, tableH = getNormalizedScreenValues(0, 120)
    local tableY = y + padY
    local cellW = (w - padX - padX) / 3
    local cellX = x + padX

    -- cell backgrounds
    renderBox(self.cellOv, cellX, tableY, cellW, tableH, self.colCellBg)
    renderBox(self.cellOv, cellX + cellW, tableY, cellW, tableH, self.colCellBg)
    renderBox(self.cellOv, cellX + cellW + cellW, tableY, cellW, tableH, self.colCellBg)

    local _, labelSize = getNormalizedScreenValues(0, 18)
    local _, valOffY = getNormalizedScreenValues(0, 44)

    renderTextLine(cellX + cellW * 0.5, tableY + tableH - padY, labelSize, "N", self.colMuted, RenderText.ALIGN_CENTER, true)
    renderTextLine(cellX + cellW * 0.5, tableY + tableH - valOffY, valueSize, fmtSigned(n, 3), self.colText, RenderText.ALIGN_CENTER, false)

    renderTextLine(cellX + cellW * 1.5, tableY + tableH - padY, labelSize, "E", self.colMuted, RenderText.ALIGN_CENTER, true)
    renderTextLine(cellX + cellW * 1.5, tableY + tableH - valOffY, valueSize, fmtSigned(e, 3), self.colText, RenderText.ALIGN_CENTER, false)

    renderTextLine(cellX + cellW * 2.5, tableY + tableH - padY, labelSize, "H", self.colMuted, RenderText.ALIGN_CENTER, true)
    renderTextLine(cellX + cellW * 2.5, tableY + tableH - valOffY, valueSize, fmtSigned(hVal, 3), self.colText, RenderText.ALIGN_CENTER, false)

    -- "Set 0" visible button (non-clickable prompt)
    local btnW = cellW * 0.9
    local _, btnH = getNormalizedScreenValues(0, 26)
    local btnX = x + w - padX - btnW
    local btnY = y + padY

    renderBox(self.headerOv, btnX, btnY, btnW, btnH, self.colCellBg)
    renderTextLine(btnX + btnW * 0.5, btnY + (btnH * 0.25), rowSize, "Set 0 (CTRL + 0)", self.colText, RenderText.ALIGN_CENTER, true)

    -- footer info
    local footerY = y + padY + tableH + padY
    renderTextLine(x + padX, footerY, rowSize, "Input:", self.colMuted, RenderText.ALIGN_LEFT, false)
    renderTextLine(x + w - padX, footerY, rowSize, self.firedOnce and "ActionEvent" or "Raw fallback", self.colText, RenderText.ALIGN_RIGHT, false)
end

-- =========================
-- Install Mission00 extensions
-- =========================
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
