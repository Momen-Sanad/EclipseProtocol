-- Handles player locomotion, dash timing, and knockback impulse blending.
local AudioSystem = require("src/systems/audio_system")
local Kinematics = require("src/utils/kinematics")
local MathUtils = require("src/utils/math_utils")

local MovementSystem = {}

-- tweakables
local IMPULSE_DECAY_RATE = 6.0    -- higher = knockback decays faster (per second)
local IMPULSE_EPSILON = 1.0       -- below this value we zero the impulse
local STAND_STILL_TIMEOUT = 0.5
local MOVE_EPSILON = 0.001
local LOW_HEALTH_NO_EFFECT_THRESHOLD = 0.995
local LOW_HEALTH_SPEED_PENALTY_MAX = 0.34
local LOW_HEALTH_DRIFT_MAX = 0.32
local LOW_HEALTH_SWAY_MAX_ANGLE = 0.42
local LOW_HEALTH_SWAY_FREQUENCY = 7.5
local LOW_HEALTH_STUMBLE_CHANCE_PER_SECOND = 1.2
local LOW_HEALTH_STUMBLE_MIN_DURATION = 0.08
local LOW_HEALTH_STUMBLE_MAX_DURATION = 0.22
local LOW_HEALTH_STUMBLE_MAX_ANGLE = 0.72
local LOW_HEALTH_SHAKE_MAX = 1.8

local function getRng()
    return (love and love.math and love.math.random) or math.random
end

local function randomUnit(rng)
    return ((rng() or 0) * 2) - 1
end

local function getLowHealthImpairment(player)
    local maxHealth = math.max(1, player.maxHealth or 1)
    local health = MathUtils.clamp(player.health or maxHealth, 0, maxHealth)
    local ratio = health / maxHealth
    if ratio >= LOW_HEALTH_NO_EFFECT_THRESHOLD then
        return 0
    end

    local severity = 1 - ratio
    -- Ease-in keeps mild damage readable while low HP becomes dramatically unstable.
    return severity * severity * (2 - severity)
end

local function updateRenderShake(player, dt, impairment, rng)
    player.impairmentTime = (player.impairmentTime or 0) + (dt or 0)
    if impairment <= 0 then
        player.renderShakeX = 0
        player.renderShakeY = 0
        return
    end

    player.impairmentSeed = player.impairmentSeed or ((rng() or 0) * math.pi * 2)
    local t = player.impairmentTime + player.impairmentSeed
    local noiseX = randomUnit(rng)
    local noiseY = randomUnit(rng)
    local shakeMag = LOW_HEALTH_SHAKE_MAX * impairment
    local waveX = math.sin((t * 12.0) + 0.7)
    local waveY = math.cos((t * 14.0) + 1.2)
    player.renderShakeX = ((waveX * 0.65) + (noiseX * 0.35)) * shakeMag
    player.renderShakeY = ((waveY * 0.65) + (noiseY * 0.35)) * shakeMag
end

local function distortInputByHealth(player, moveX, moveY, dt, impairment, rng)
    if impairment <= 0 or (moveX == 0 and moveY == 0) then
        player.stumbleTimer = 0
        return moveX, moveY, 1.0
    end

    local nx, ny = Kinematics.normalize(moveX, moveY)
    player.impairmentSeed = player.impairmentSeed or ((rng() or 0) * math.pi * 2)

    local swayAngle = math.sin((player.impairmentTime or 0) * LOW_HEALTH_SWAY_FREQUENCY + player.impairmentSeed)
        * LOW_HEALTH_SWAY_MAX_ANGLE
        * impairment
    nx, ny = MathUtils.rotate(nx, ny, swayAngle)

    player.stumbleTimer = math.max(0, (player.stumbleTimer or 0) - (dt or 0))
    if player.stumbleTimer <= 0 then
        local stumbleChance = LOW_HEALTH_STUMBLE_CHANCE_PER_SECOND * impairment * impairment
        if (rng() or 0) < (stumbleChance * (dt or 0)) then
            local durationRange = LOW_HEALTH_STUMBLE_MAX_DURATION - LOW_HEALTH_STUMBLE_MIN_DURATION
            player.stumbleTimer = LOW_HEALTH_STUMBLE_MIN_DURATION + (durationRange * (rng() or 0))
            player.stumbleSign = ((rng() or 0) < 0.5) and -1 or 1
        end
    end

    if player.stumbleTimer > 0 then
        local stumbleAngle = player.stumbleSign * LOW_HEALTH_STUMBLE_MAX_ANGLE * (0.35 + (impairment * 0.65))
        nx, ny = MathUtils.rotate(nx, ny, stumbleAngle)
    end

    local driftMag = LOW_HEALTH_DRIFT_MAX * impairment
    nx = nx + (randomUnit(rng) * driftMag)
    ny = ny + (randomUnit(rng) * driftMag)
    nx, ny = Kinematics.normalize(nx, ny)

    local speedMultiplier = 1 - (LOW_HEALTH_SPEED_PENALTY_MAX * impairment)
    return nx, ny, speedMultiplier
end

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
    local rng = getRng()
    local impairment = getLowHealthImpairment(player)
    updateRenderShake(player, dt, impairment, rng)

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

    -- update last move direction for dash fallback
    if moveX ~= 0 or moveY ~= 0 then
        player.lastMoveX = moveX
        player.lastMoveY = moveY
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
    else
        if not hasMoveInput then
            getWalkSpeed(player, baseSpeed, dt, false)
            Kinematics.setInputVelocity(player, 0, 0)
        else
            local nx, ny, speedMultiplier = distortInputByHealth(player, moveX, moveY, dt, impairment, rng)
            local walkSpeed = getWalkSpeed(player, baseSpeed, dt, true)
            Kinematics.setInputVelocity(player, nx * walkSpeed * speedMultiplier, ny * walkSpeed * speedMultiplier)
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
