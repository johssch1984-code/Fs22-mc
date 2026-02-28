-- FS22 Survey HUD (CTRL+L)
-- v1.0.3.1
-- KEEP: Mission00 registration + raw CTRL+L fallback

SimpleHudAD = {
    isVisible = false,
    actionEventId = nil,
    firedOnce = false,      -- true if action event callback ever fires
    lastRawDown = false,    -- debounce for raw polling
    debug = true,

    -- overlays (created lazily)
    bgOv = nil,
    headerOv = nil,
    lineOv = nil,
    cellOv = nil
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

-- data (optional; can be provided by other scripts)
SimpleHudAD.data = {
    n = nil,
    e = nil,
    h = nil,
    cutFill = nil
}

-- Load modular libraries (keep runtime behavior)
local modDirectory = g_currentModDirectory or ""
source(modDirectory .. "scripts/SimpleHudAD_Hud.lua")
source(modDirectory .. "scripts/SimpleHudAD_Toolpoint.lua")
source(modDirectory .. "scripts/SimpleHudAD_Updater.lua")

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
