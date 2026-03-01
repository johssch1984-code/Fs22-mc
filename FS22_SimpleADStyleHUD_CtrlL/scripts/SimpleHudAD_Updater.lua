-- FS22 Survey HUD - Updater / input library
-- v1.0.3.1

local function dbg(msg)
    if SimpleHudAD.debug then
        print("[SimpleHudAD] " .. msg)
    end
end

SimpleHudAD.zeroH = SimpleHudAD.zeroH or nil
SimpleHudAD.actionEventIdSetZero = SimpleHudAD.actionEventIdSetZero or nil

function SimpleHudAD:setSurveyData(n, e, h, cutFill)
    self.data.n = n
    self.data.e = e
    self.data.h = h
    self.data.cutFill = cutFill
end

local function updateSurveyValues(self, mission)
    if mission == nil or SimpleHudAD.toolpoint == nil then
        return
    end

    local x, y, z = SimpleHudAD.toolpoint:getToolpointWorldPosition(mission)
    if x == nil then
        return
    end

    -- Display convention: N = Z, E = X, H = Y (meters)
    local n = z
    local e = x
    local h = y

    -- Initialize target height only once (first valid sample)
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
        if g_currentMission ~= nil then
            local x, y, z = SimpleHudAD.toolpoint:getToolpointWorldPosition(g_currentMission)
            if y ~= nil then
                self.zeroH = y
                dbg("set zero -> " .. tostring(self.zeroH))
            end
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
    if mission ~= nil then
        self._lastRawZeroDown = self._lastRawZeroDown or false
        local rawZeroDown = isRawCtrl0Down()
        if rawZeroDown and not self._lastRawZeroDown then
            local x, y, z = SimpleHudAD.toolpoint:getToolpointWorldPosition(mission)
            if y ~= nil then
                self.zeroH = y
                dbg("set zero -> " .. tostring(self.zeroH) .. " (via RAW fallback)")
            end
        end
        self._lastRawZeroDown = rawZeroDown
    end

    if mission ~= nil and mission.inputManager ~= nil then
        if self.actionEventId ~= nil then
            mission.inputManager:setActionEventActive(self.actionEventId, true)
        end
        if self.actionEventIdSetZero ~= nil then
            mission.inputManager:setActionEventActive(self.actionEventIdSetZero, true)
        end
    end
end
