-- FS22 Survey HUD - Toolpoint / kinematics library
-- v1.0.3.1

SimpleHudAD.toolpoint = SimpleHudAD.toolpoint or {}

-- Returns a node used as the reference toolpoint for surveying.
-- Keeps behavior stable: for now, prefer controlled vehicle rootNode, else player rootNode.
function SimpleHudAD.toolpoint:getToolpointNode(mission)
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

-- Returns world position (x,y,z) of the current toolpoint node.
function SimpleHudAD.toolpoint:getToolpointWorldPosition(mission)
    local node = self:getToolpointNode(mission)
    if node == nil then
        return nil
    end

    local x, y, z = getWorldTranslation(node)
    return x, y, z
end
