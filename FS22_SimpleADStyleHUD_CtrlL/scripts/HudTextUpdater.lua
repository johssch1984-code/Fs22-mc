-- scripts/HudTextUpdater.lua
-- Lock behavior (requested):
--   - ONLY lock while the player is inside a vehicle (mission.controlledVehicle ~= nil)
--   - If you TAB to another vehicle -> controlledVehicle changes -> release + re-lock for new vehicle
--   - If you exit to on-foot (controlledVehicle == nil) -> release

HudTextUpdater = {}

HudTextUpdater.lockedNode = nil
HudTextUpdater.lockedOwnerName = nil
HudTextUpdater.lockedOwnerType = nil
HudTextUpdater.lastControlledVehicle = nil

local function findChild(node, name, depth)
    if node == nil then return nil end
    depth = depth or 0
    if depth > 64 then return nil end
    if getName(node) == name then return node end
    for i=0, getNumOfChildren(node)-1 do
        local c = getChildAt(node, i)
        local f = findChild(c, name, depth+1)
        if f ~= nil then return f end
    end
    return nil
end

local function getRoot(obj)
    if obj == nil then return nil end
    if obj.rootNode ~= nil then return obj.rootNode end
    if obj.components ~= nil and obj.components[1] ~= nil then
        return obj.components[1].node
    end
    return nil
end

local function resolveOnObject(obj)
    local root = getRoot(obj)
    if root == nil then return nil end

    local n = findChild(root, "groundReferenceNode")
    if n ~= nil then return n end
    n = findChild(root, "tipReferenceNode")
    if n ~= nil then return n end
    n = findChild(root, "tip")
    if n ~= nil then return n end

    return nil
end

local function resolveBucketToolpoint(controlledVehicle)
    if controlledVehicle == nil then return nil, nil end

    -- Prefer attached implements first (bucket is usually an implement)
    if controlledVehicle.getAttachedImplements ~= nil then
        for _, impl in ipairs(controlledVehicle:getAttachedImplements()) do
            local t = resolveOnObject(impl.object)
            if t ~= nil then
                return t, impl.object
            end
        end
    end

    -- Fallback: controlled vehicle itself (if it *is* the bucket)
    local t = resolveOnObject(controlledVehicle)
    if t ~= nil then
        return t, controlledVehicle
    end

    return nil, nil
end

local function ownerDebugName(owner)
    if owner == nil then return "nil", "nil" end
    local name = owner.getName and owner:getName() or nil
    if name == nil then name = owner.configFileName or tostring(owner) end
    local t = owner.typeName or "unknownType"
    return tostring(name), tostring(t)
end

local function releaseLock(reason)
    if HudTextUpdater.lockedNode ~= nil then
        print(string.format("[SimpleHudAD] LOCK RELEASED (%s). Was owner=%s type=%s",
            tostring(reason), tostring(HudTextUpdater.lockedOwnerName), tostring(HudTextUpdater.lockedOwnerType)))
    end
    HudTextUpdater.lockedNode = nil
    HudTextUpdater.lockedOwnerName = nil
    HudTextUpdater.lockedOwnerType = nil
end

function HudTextUpdater.updateText(hud, mission)
    local controlled = (mission ~= nil) and mission.controlledVehicle or nil

    -- Release if player is not in a vehicle
    if controlled == nil then
        if HudTextUpdater.lastControlledVehicle ~= nil then
            releaseLock("exit vehicle")
        end
        HudTextUpdater.lastControlledVehicle = nil
        hud.dynamicText = "E=---  N=---  H=---"
        hud.debugLine = "Lock: none (on foot)"
        return
    end

    -- Release + re-lock if TAB switched to another vehicle
    if HudTextUpdater.lastControlledVehicle ~= nil and controlled ~= HudTextUpdater.lastControlledVehicle then
        releaseLock("TAB switched vehicle")
    end
    HudTextUpdater.lastControlledVehicle = controlled

    -- Acquire lock if missing
    if HudTextUpdater.lockedNode == nil then
        local tp, owner = resolveBucketToolpoint(controlled)
        if tp ~= nil then
            HudTextUpdater.lockedNode = tp
            HudTextUpdater.lockedOwnerName, HudTextUpdater.lockedOwnerType = ownerDebugName(owner)
            print(string.format("[SimpleHudAD] LOCK ACQUIRED: owner=%s type=%s node=%s",
                HudTextUpdater.lockedOwnerName, HudTextUpdater.lockedOwnerType, getName(tp)))
        end
    end

    if HudTextUpdater.lockedNode == nil then
        hud.dynamicText = "E=---  N=---  H=---"
        hud.debugLine = "Lock: none (no bucket found)"
        return
    end

    local x, y, z = getWorldTranslation(HudTextUpdater.lockedNode)
    hud.dynamicText = string.format("E=%.3f  N=%.3f  H=%.3f", x, z, y)
    if hud.zeroH ~= nil then
        hud.cutFill = y - hud.zeroH
    else
        hud.cutFill = nil
    end
    hud.debugLine = string.format("Lock: %s (%s)", tostring(HudTextUpdater.lockedOwnerName), tostring(HudTextUpdater.lockedOwnerType))
end
