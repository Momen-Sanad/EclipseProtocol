-- Handles player locomotion, dash timing, and knockback impulse blending.
local AudioSystem = require("src/systems/audio_system")
local Kinematics = require("src/utils/kinematics")

local MovementSystem = {}

-- tweakables
local IMPULSE_DECAY_RATE = 6.0    -- higher = knockback decays faster (per second)
local IMPULSE_EPSILON = 1.0       -- below this value we zero the impulse
local STAND_STILL_TIMEOUT = 0.5
local MOVE_EPSILON = 0.001

local function syncMoveFlags(player)
    local moveX, moveY, speed = Kinematics.normalize(player.vx or 0, player.vy or 0)
    player.moveX = moveX
    player.moveY = moveY
    if player.isMoving == nil then
        player.isMoving = speed > 0 or player.isDashing
    end
end

local function getWalkSpeed(player, baseSpeed, dt, hasInput)
    if not hasInput then
        player.moveHeldTime = 0
        return 0
    end

    local rampDuration = math.max(0, player.moveRampDuration or 0)
    local startSpeed = math.max(0, math.min(baseSpeed, player.moveStartSpeed or (baseSpeed * 0.35)))

    if rampDuration <= 0 or startSpeed >= baseSpeed then
        player.moveHeldTime = rampDuration
        return baseSpeed
    end

    player.moveHeldTime = math.min(rampDuration, (player.moveHeldTime or 0) + (dt or 0))
    local t = player.moveHeldTime / rampDuration
    return startSpeed + ((baseSpeed - startSpeed) * t)
end

local function ensureFootstepSource(player)
    if player.footstepSource and player.footstepSourcePath == player.footstepSoundPath then
        return player.footstepSource
    end

    player.footstepSource = nil
    player.footstepSourcePath = nil
    local soundPath = player.footstepSoundPath or "assets/audio/sfx/Footsteps.mp3"
    if not (love and love.filesystem and love.filesystem.getInfo(soundPath)) then
        return nil
    end

    local ok, source = pcall(love.audio.newSource, soundPath, "static")
    if not ok or not source then
        return nil
    end

    source:setLooping(false)
    player.footstepSource = source
    player.footstepSourcePath = soundPath
    return source
end

local function updateFootsteps(player)
    local source = ensureFootstepSource(player)
    if not source then
        return
    end

    local sfxMix = (AudioSystem.getSfxVolume and AudioSystem.getSfxVolume()) or 1
    local stepVolume = math.max(0, math.min(1, (player.footstepVolume or 0.35) * sfxMix))
    source:setVolume(stepVolume)

    if player.isMoving and not player.isDashing then
        -- Keep footsteps going while moving: if one clip ends, restart it.
        if not source:isPlaying() then
            source:play()
        end
    elseif source:isPlaying() then
        source:stop()
    end
end

function MovementSystem.update(player, input, dt, bounds)
    -- Combines live input with temporary impulses, then clamps the result to the play area.
    if not player then return end
    dt = dt or 0

    -- Ensure input velocity and impulse velocity can be composed into one body velocity.
    Kinematics.ensureCompositeVelocity(player)

    -- Hit-reaction lock: player blinks/invulnerable and cannot move during this window.
    if (player.damageLockTimer or 0) > 0 then
        Kinematics.setInputVelocity(player, 0, 0)
        player.vx_impulse = 0
        player.vy_impulse = 0
        Kinematics.stop(player)
        player.isDashing = false
        player.dashTimer = 0
        player.moveHeldTime = 0
        player.moveX = 0
        player.moveY = 0
        player.isMoving = false
        player.standStillTimer = 0
        updateFootsteps(player)
        return
    end

    local prevX = player.x or 0
    local prevY = player.y or 0

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

    local dashEnergyCost = math.max(0, player.dashEnergyCost or 0)
    local hasTrackedEnergy = type(player.energy) == "number"
    local hasDashEnergy = true
    if hasTrackedEnergy then
        hasDashEnergy = player.energy >= dashEnergyCost
    end

    -- start dash if requested and available
    if dashPressed and not player.isDashing and (player.dashCooldownTimer or 0) <= 0 and hasDashEnergy then
        local dirX, dirY = moveX, moveY
        if dirX == 0 and dirY == 0 then
            dirX = player.lastMoveX or 0
            dirY = player.lastMoveY or 0
        end
        if dirX ~= 0 or dirY ~= 0 then
            dirX, dirY = Kinematics.normalize(dirX, dirY)
            if hasTrackedEnergy and dashEnergyCost > 0 then
                player.energy = math.max(0, player.energy - dashEnergyCost)
            end
            player.isDashing = true
            player.dashTimer = player.dashDuration or 0.18
            player.dashDirX = dirX
            player.dashDirY = dirY
            player.dashCooldownTimer = player.dashCooldown or 0.35
            -- Play the dash cue at the exact moment the movement burst begins.
            AudioSystem.playSfx(player.dashSoundPath or "assets/audio/sfx/Dash.mp3")
        end
    end

    local hasMoveInput = moveX ~= 0 or moveY ~= 0

    -- base speed
    local baseSpeed = player.speed or 0

    -- compute input-driven velocity (vx_input, vy_input)
    if player.isDashing then
        -- override input with dash direction & speed
        Kinematics.setInputVelocity(
            player,
            (player.dashDirX or 0) * (player.dashSpeed or (baseSpeed * 2.5)),
            (player.dashDirY or 0) * (player.dashSpeed or (baseSpeed * 2.5))
        )

        player.dashTimer = (player.dashTimer or 0) - dt
        if player.dashTimer <= 0 then
            player.isDashing = false
            player.dashTimer = 0
        end
    else
        if not hasMoveInput then
            getWalkSpeed(player, baseSpeed, dt, false)
            Kinematics.setInputVelocity(player, 0, 0)
        else
            local nx, ny = Kinematics.normalize(moveX, moveY)
            local walkSpeed = getWalkSpeed(player, baseSpeed, dt, true)
            Kinematics.setInputVelocity(player, nx * walkSpeed, ny * walkSpeed)
        end
    end

    -- Compose the movement input and knockback impulse into one velocity vector.
    Kinematics.composeVelocity(player)
    Kinematics.integrate(player, dt, bounds)

    -- decay impulses so knockback fades naturally
    Kinematics.decayImpulse(player, IMPULSE_DECAY_RATE, dt, IMPULSE_EPSILON)
    Kinematics.composeVelocity(player)
    syncMoveFlags(player)

    local movedX = math.abs((player.x or 0) - prevX)
    local movedY = math.abs((player.y or 0) - prevY)
    local movedThisFrame = movedX > MOVE_EPSILON or movedY > MOVE_EPSILON

    if movedThisFrame then
        player.isMoving = true
        player.standStillTimer = 0
    else
        player.standStillTimer = (player.standStillTimer or 0) + dt
        if player.standStillTimer > STAND_STILL_TIMEOUT then
            player.isMoving = false
        end
    end

    updateFootsteps(player)
end

return MovementSystem
