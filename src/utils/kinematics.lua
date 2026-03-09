-- Shared helpers for velocity-driven movement, impulses, and positional corrections.
local Kinematics = {}

function Kinematics.normalize(vx, vy)
    -- Returns normalized direction plus original magnitude.
    local len = math.sqrt((vx or 0) * (vx or 0) + (vy or 0) * (vy or 0))
    if len == 0 then
        return 0, 0, 0
    end

    return (vx or 0) / len, (vy or 0) / len, len
end

function Kinematics.capturePreviousPosition(body)
    -- Snapshot before movement/collision resolution so other systems can compare motion.
    if not body then
        return
    end

    body.prevX = body.x or 0
    body.prevY = body.y or 0
end

function Kinematics.setVelocity(body, vx, vy)
    -- Writes final composed velocity used for frame integration.
    if not body then
        return
    end

    body.vx = vx or 0
    body.vy = vy or 0
end

function Kinematics.stop(body)
    -- Convenience helper for hard-stopping an entity.
    Kinematics.setVelocity(body, 0, 0)
end

function Kinematics.translate(body, dx, dy)
    -- Adds delta movement directly to position.
    if not body then
        return
    end

    body.x = (body.x or 0) + (dx or 0)
    body.y = (body.y or 0) + (dy or 0)
end

function Kinematics.moveTo(body, x, y)
    -- Absolute placement helper used by resets/spawns.
    if not body then
        return
    end

    if x ~= nil then
        body.x = x
    end
    if y ~= nil then
        body.y = y
    end
end

function Kinematics.clampPosition(body, bounds)
    -- Restricts coordinates inside a min/max rectangle.
    if not body or not bounds then
        return
    end

    if bounds.minX ~= nil and bounds.maxX ~= nil then
        body.x = math.max(bounds.minX, math.min(body.x or 0, bounds.maxX))
    end
    if bounds.minY ~= nil and bounds.maxY ~= nil then
        body.y = math.max(bounds.minY, math.min(body.y or 0, bounds.maxY))
    end
end

function Kinematics.integrate(body, dt, bounds)
    -- Euler integration step (position += velocity * dt), then optional bounds clamp.
    if not body then
        return
    end

    body.x = (body.x or 0) + (body.vx or 0) * (dt or 0)
    body.y = (body.y or 0) + (body.vy or 0) * (dt or 0)

    Kinematics.clampPosition(body, bounds)
end

function Kinematics.ensureCompositeVelocity(body)
    -- Initializes the split velocity channels used by movement + impulses.
    if not body then
        return
    end

    body.vx = body.vx or 0
    body.vy = body.vy or 0
    body.vx_input = body.vx_input or 0
    body.vy_input = body.vy_input or 0
    body.vx_impulse = body.vx_impulse or 0
    body.vy_impulse = body.vy_impulse or 0
end

function Kinematics.setInputVelocity(body, vx, vy)
    -- Records movement contributed by player/AI input this frame.
    if not body then
        return
    end

    body.vx_input = vx or 0
    body.vy_input = vy or 0
end

function Kinematics.addImpulse(body, vx, vy)
    -- Adds knockback/dash-like transient velocity on top of input velocity.
    if not body then
        return
    end

    body.vx_impulse = (body.vx_impulse or 0) + (vx or 0)
    body.vy_impulse = (body.vy_impulse or 0) + (vy or 0)
end

function Kinematics.composeVelocity(body)
    -- Combines input + impulse channels into the final `vx/vy`.
    if not body then
        return 0, 0
    end

    local vx = (body.vx_input or 0) + (body.vx_impulse or 0)
    local vy = (body.vy_input or 0) + (body.vy_impulse or 0)
    Kinematics.setVelocity(body, vx, vy)

    return vx, vy
end

function Kinematics.decayImpulse(body, rate, dt, epsilon)
    -- Dampens impulse over time and snaps tiny values to zero for stability.
    if not body then
        return
    end

    local decay = math.max(0, 1 - (rate or 0) * (dt or 0))
    body.vx_impulse = (body.vx_impulse or 0) * decay
    body.vy_impulse = (body.vy_impulse or 0) * decay

    local minValue = epsilon or 0
    if math.abs(body.vx_impulse) < minValue then
        body.vx_impulse = 0
    end
    if math.abs(body.vy_impulse) < minValue then
        body.vy_impulse = 0
    end
end

return Kinematics
