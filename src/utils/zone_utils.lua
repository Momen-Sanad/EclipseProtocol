-- Shared geometry helpers for operations against protected rectangular zones.
local MathUtils = require("src/utils/math_utils")
local CollisionSystem = require("src/systems/collision_system")

local ZoneUtils = {}

local function getZoneRect(zone, padding)
    local pad = math.max(0, padding or 0)
    local zx = (zone and zone.x or 0) - pad
    local zy = (zone and zone.y or 0) - pad
    local zw = (zone and (zone.width or zone.size) or 0) + (pad * 2)
    local zh = (zone and (zone.height or zone.size) or 0) + (pad * 2)
    return zx, zy, zw, zh
end

function ZoneUtils.overlapsRectWithZones(x, y, w, h, zones, padding)
    if type(zones) ~= "table" or #zones == 0 then
        return false
    end

    for _, zone in ipairs(zones) do
        local zx, zy, zw, zh = getZoneRect(zone, padding)
        if CollisionSystem.overlaps(x, y, w, h, zx, zy, zw, zh) then
            return true
        end
    end

    return false
end

function ZoneUtils.circleIntersectsZones(cx, cy, radius, zones, padding)
    if type(zones) ~= "table" or #zones == 0 then
        return false
    end

    local r = math.max(0, radius or 0)
    local rangeSq = r * r

    for _, zone in ipairs(zones) do
        local zx, zy, zw, zh = getZoneRect(zone, padding)
        local closestX = MathUtils.clamp(cx, zx, zx + zw)
        local closestY = MathUtils.clamp(cy, zy, zy + zh)
        if MathUtils.distanceSquared(cx, cy, closestX, closestY) <= rangeSq then
            return true
        end
    end

    return false
end

return ZoneUtils
