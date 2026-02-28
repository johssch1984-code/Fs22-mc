-- FS22 Survey HUD - Updater / input library
-- v1.0.3.1

local function dbg(msg)
    if SimpleHudAD.debug then
        print("[SimpleHudAD] " .. msg)
    end
end

function SimpleHudAD:setSurveyData(n, e, h, cutFill)
    self.data.n = n
    self.data.e = e
    self.data.h = h
    self.data.cutFill = cutFill
end

-- =========================
-- Action-event callback
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

-- =========================
-- Mission00 hook points
-- =========================
function SimpleHudAD:onMissionLoadMapFinished(mission)
    if mission == nil or mission.inputManager == nil then
        dbg("ERROR: mission/inputManager not ready in loadMapFinished")
        return
    end

    if self.actionEventId ~= nil then
        return
    end

    local actionId = InputAction.TOGGLE_SIMPLE_HUD
    if actionId == nil then
        actionId = InputAction["TOGGLE_SIMPLE_HUD"]
    end

    if actionId == nil then
        dbg("ERROR: InputAction TOGGLE_SIMPLE_HUD is nil")
        return
    end

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

    dbg(string.format("registered via Mission00.inputManager, actionEventId=%s actionId=%s",
        tostring(self.actionEventId), tostring(actionId)))
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

function SimpleHudAD:onMissionUpdate(mission, dt)
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
