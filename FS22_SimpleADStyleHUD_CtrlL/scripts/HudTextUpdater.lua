-- scripts/HudTextUpdater.lua
-- Updates the HUD text each tick.
-- Toolpoint definition:
--   - Prefer workArea.groundReferenceNode
--   - Else use midpoint between workArea.start and workArea.width

HudTextUpdater = {}

local function tryGetToolpoint(object)
    if object == nil then return nil end
    local spec = object.spec_workArea
    if spec == nil or spec.workAreas == nil then
        return nil
    end

    for _, wa in ipairs(spec.workAreas) do
        if wa.groundReferenceNode ~= nil then
            local x, y, z = getWorldTranslation(wa.groundReferenceNode)
            return x, y, z
        end

        if wa.start ~= nil and wa.width ~= nil then
            local sx, sy, sz = getWorldTranslation(wa.start)
            local wx, wy, wz = getWorldTranslation(wa.width)
            return (sx + wx) * 0.5, (sy + wy) * 0.5, (sz + wz) * 0.5
        end
    end

    return nil
end

local function findFirstToolpoint(vehicle)
    local x, y, z = tryGetToolpoint(vehicle)
    if x ~= nil then return x, y, z end

    if vehicle == nil or vehicle.getAttachedImplements == nil then
        return nil
    end

    local function walk(attached)
        for _, impl in ipairs(attached) do
            local obj = impl.object
            local tx, ty, tz = tryGetToolpoint(obj)
            if tx ~= nil then
                return tx, ty, tz
            end
            if obj ~= nil and obj.getAttachedImplements ~= nil then
                local rtx, rty, rtz = walk(obj:getAttachedImplements())
                if rtx ~= nil then return rtx, rty, rtz end
            end
        end
        return nil
    end

    return walk(vehicle:getAttachedImplements())
end

function HudTextUpdater.updateText(hud, mission, dt)
    local vehicle = mission ~= nil and mission.controlledVehicle or nil
    if vehicle == nil then
        hud.dynamicText = "Distance: n/a (no vehicle)"
        return
    end

    local tx, ty, tz = findFirstToolpoint(vehicle)
    if tx == nil then
        hud.dynamicText = "Distance: n/a (no workArea toolpoint found)"
        return
    end

    -- FS22: distance to ground plane y=0
    local dist, px, py, pz = DistanceToPlane.distanceToYPlane(tx, ty, tz, 0)

    hud.dynamicText = string.format(
        "Distance to h=%.3f on global x,y,z=(%.3f, %.3f, %.3f) from bucket tip",
        dist, px, py, pz
    )
end
