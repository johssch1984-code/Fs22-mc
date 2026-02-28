-- scripts/DistanceToPlane.lua
-- Utility functions for distance calculations in FS22 world coordinates.
-- IMPORTANT: In FS22, Y is the vertical axis. The ground plane is roughly y=0 (not z=0).

DistanceToPlane = {}

--- Distance from a point to the horizontal plane y = planeY, and the projected point (x, planeY, z).
-- @return distance, projX, projY, projZ
function DistanceToPlane.distanceToYPlane(x, y, z, planeY)
    planeY = planeY or 0
    local distance = math.abs(y - planeY)
    return distance, x, planeY, z
end

--- If you REALLY want the plane z = planeZ (treat Z as vertical), use this.
function DistanceToPlane.distanceToZPlane(x, y, z, planeZ)
    planeZ = planeZ or 0
    local distance = math.abs(z - planeZ)
    return distance, x, y, planeZ
end
