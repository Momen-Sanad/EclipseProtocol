-- Reusable scalar/vector geometry helpers used across gameplay systems.
local MathUtils = {}

function MathUtils.dot(ax, ay, bx, by)
    return (ax or 0) * (bx or 0) + (ay or 0) * (by or 0)
end

function MathUtils.distanceSquared(ax, ay, bx, by)
    local dx = (ax or 0) - (bx or 0)
    local dy = (ay or 0) - (by or 0)
    return (dx * dx) + (dy * dy)
end

function MathUtils.rotate(x, y, angle)
    local c = math.cos(angle or 0)
    local s = math.sin(angle or 0)
    local vx = x or 0
    local vy = y or 0
    return vx * c - vy * s, vx * s + vy * c
end

function MathUtils.aabb(x1, y1, w1, h1, x2, y2, w2, h2)
    return (x1 or 0) < (x2 or 0) + (w2 or 0)
        and (x2 or 0) < (x1 or 0) + (w1 or 0)
        and (y1 or 0) < (y2 or 0) + (h2 or 0)
        and (y2 or 0) < (y1 or 0) + (h1 or 0)
end

function MathUtils.segmentIntersectsAabb(x1, y1, x2, y2, rx, ry, rw, rh)
    -- Liang-Barsky clipping of a segment against an axis-aligned rectangle.
    local sx = x1 or 0
    local sy = y1 or 0
    local ex = x2 or 0
    local ey = y2 or 0
    local bx = rx or 0
    local by = ry or 0
    local bw = rw or 0
    local bh = rh or 0

    local dx = ex - sx
    local dy = ey - sy
    local tMin = 0
    local tMax = 1

    local function clip(p, q)
        if p == 0 then
            return q >= 0
        end

        local r = q / p
        if p < 0 then
            if r > tMax then
                return false
            end
            if r > tMin then
                tMin = r
            end
        else
            if r < tMin then
                return false
            end
            if r < tMax then
                tMax = r
            end
        end

        return true
    end

    if not clip(-dx, sx - bx) then
        return false
    end
    if not clip(dx, (bx + bw) - sx) then
        return false
    end
    if not clip(-dy, sy - by) then
        return false
    end
    if not clip(dy, (by + bh) - sy) then
        return false
    end

    return tMax >= tMin
end

return MathUtils
