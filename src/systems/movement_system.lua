-- Handles player locomotion, dash timing, and knockback impulse blending.
local AudioSystem = require("src/systems/audio_system")

local MovementSystem = {}

-- tweakables
local IMPULSE_DECAY_RATE = 6.0    -- higher = knockback decays faster (per second)
local IMPULSE_EPSILON = 1.0       -- below this value we zero the impulse

local function safeInitPlayerVels(player)
    player.vx_input   = player.vx_input   or 0
    player.vy_input   = player.vy_input   or 0
    player.vx_impulse = player.vx_impulse or 0
    player.vy_impulse = player.vy_impulse or 0
end

function MovementSystem.update(player, input, dt, bounds)
    -- Combines live input with temporary impulses, then clamps the result to the play area.
    if not player then return end
    dt = dt or 0

    -- ensure velocity fields exist (so collision_system can add impulses safely)
    safeInitPlayerVels(player)

    -- read move input
    local moveX, moveY = 0, 0
    if input and input.getMoveDir then
        moveX, moveY = input.getMoveDir()
    end

    -- dash pressed
    local dashPressed = input and input.dashPressed and input.dashPressed() or false

    -- update last move direction for dash fallback
    if moveX ~= 0 or moveY ~= 0 then
        player.lastMoveX = moveX
        player.lastMoveY = moveY
    end

    -- dash cooldown timer tick
    if player.dashCooldownTimer and player.dashCooldownTimer > 0 then
        player.dashCooldownTimer = math.max(0, player.dashCooldownTimer - dt)
    end

    -- start dash if requested and available
    if dashPressed and not player.isDashing and (player.dashCooldownTimer or 0) <= 0 then
        local dirX, dirY = moveX, moveY
        if dirX == 0 and dirY == 0 then
            dirX = player.lastMoveX or 0
            dirY = player.lastMoveY or 0
        end
        if dirX ~= 0 or dirY ~= 0 then
            local len = math.sqrt(dirX * dirX + dirY * dirY)
            if len == 0 then len = 1 end
            dirX = dirX / len
            dirY = dirY / len
            player.isDashing = true
            player.dashTimer = player.dashDuration or 0.18
            player.dashDirX = dirX
            player.dashDirY = dirY
            player.dashCooldownTimer = player.dashCooldown or 0.35
            -- Play the dash cue at the exact moment the movement burst begins.
            AudioSystem.playSfx(player.dashSoundPath or "assets/audio/sfx/Dash.mp3")
        end
    end

    -- base speed
    local baseSpeed = player.speed or 0

    -- compute input-driven velocity (vx_input, vy_input)
    if player.isDashing then
        -- override input with dash direction & speed
        player.vx_input = (player.dashDirX or 0) * (player.dashSpeed or (baseSpeed * 2.5))
        player.vy_input = (player.dashDirY or 0) * (player.dashSpeed or (baseSpeed * 2.5))

        player.dashTimer = (player.dashTimer or 0) - dt
        if player.dashTimer <= 0 then
            player.isDashing = false
            player.dashTimer = 0
        end
    else

        if moveX == 0 and moveY == 0 then
            player.vx_input = 0
            player.vy_input = 0
        else
            local len = math.sqrt(moveX * moveX + moveY * moveY)
            if len == 0 then len = 1 end
            local nx = moveX / len
            local ny = moveY / len
            player.vx_input = nx * baseSpeed
            player.vy_input = ny * baseSpeed
        end
    end

    -- expose move flags for other systems / drawing
    player.moveX = (player.vx_input ~= 0) and (player.vx_input / (baseSpeed ~= 0 and baseSpeed or 1)) or 0
    player.moveY = (player.vy_input ~= 0) and (player.vy_input / (baseSpeed ~= 0 and baseSpeed or 1)) or 0
    player.isMoving = (player.moveX ~= 0 or player.moveY ~= 0) or player.isDashing

    -- total velocity is input + impulse
    local totalVx = (player.vx_input or 0) + (player.vx_impulse or 0)
    local totalVy = (player.vy_input or 0) + (player.vy_impulse or 0)

    -- integrate position using total velocity
    player.x = (player.x or 0) + totalVx * dt
    player.y = (player.y or 0) + totalVy * dt

    -- window bounds clamp
    if bounds then
        player.x = math.max(bounds.minX, math.min(player.x, bounds.maxX))
        player.y = math.max(bounds.minY, math.min(player.y, bounds.maxY))
    end

    -- decay impulses so knockback fades naturally
    local decay = math.max(0, 1 - IMPULSE_DECAY_RATE * dt)
    player.vx_impulse = (player.vx_impulse or 0) * decay
    player.vy_impulse = (player.vy_impulse or 0) * decay

    if math.abs(player.vx_impulse) < IMPULSE_EPSILON then player.vx_impulse = 0 end
    if math.abs(player.vy_impulse) < IMPULSE_EPSILON then player.vy_impulse = 0 end
end

return MovementSystem
