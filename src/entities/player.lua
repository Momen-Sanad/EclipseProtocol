-- Player entity data factory.
-- Gameplay systems mutate these fields; animation is owned by src/systems/animation_system.lua.
local Player = {}

function Player.new(config)
    local cfg = config or {}
    local maxHealth = cfg.maxHealth or 100
    local maxEnergy = cfg.maxEnergy or 100

    return {
        x = cfg.x or 0,
        y = cfg.y or 0,

        -- Movement / dash mechanics.
        speed = cfg.speed or 300,
        moveStartSpeed = cfg.moveStartSpeed or ((cfg.speed or 300) * 0.35),
        moveRampDuration = cfg.moveRampDuration or 0.45,
        moveHeldTime = 0,
        dashSpeed = cfg.dashSpeed or ((cfg.speed or 300) * 2.5),
        dashDuration = cfg.dashDuration or 0.18,
        dashCooldown = cfg.dashCooldown or 5.0,
        dashEnergyCost = cfg.dashEnergyCost or 20,
        dashTimer = 0,
        dashCooldownTimer = 0,
        isDashing = false,
        isMoving = false,
        standStillTimer = 0,

        -- Audio hooks consumed by movement/collision systems.
        dashSoundPath = cfg.dashSoundPath or "assets/audio/sfx/Dash.wav",
        damageSoundPath = cfg.damageSoundPath or "assets/audio/sfx/Damage.mp3",
        footstepSoundPath = cfg.footstepSoundPath or "assets/audio/sfx/Footsteps.mp3",
        footstepVolume = cfg.footstepVolume or 0.35,
        footstepSource = nil,
        footstepSourcePath = nil,

        -- Health / energy.
        maxHealth = maxHealth,
        health = cfg.health or maxHealth,
        maxEnergy = maxEnergy,
        energy = cfg.energy or maxEnergy,

        -- Hit-reaction state.
        damageFlickerCount = math.max(1, math.floor(cfg.damageFlickerCount or 2)),
        damageFlickerDuration = math.max(0.01, cfg.damageFlickerDuration or 0.4),
        damageFlickerTimer = 0,
        damageLockTimer = 0,

        -- Animation configuration consumed by AnimationSystem.
        animationConfig = {
            spritePath = cfg.spritePath or "assets/sprites/player/Robot.png",
            animMode = cfg.animMode,
            frameWidth = cfg.frameWidth,
            frameHeight = cfg.frameHeight,
            frameCols = cfg.frameCols,
            frameRows = cfg.frameRows,
            frameLeft = cfg.frameLeft,
            frameTop = cfg.frameTop,
            frameSpacing = cfg.frameSpacing,
            defaultAnim = cfg.defaultAnim,
            frameDuration = cfg.frameDuration or 0.12,
            stateFrameCounts = cfg.stateFrameCounts,
            stateFrameDurations = cfg.stateFrameDurations,
            stateRows = cfg.stateRows,
            stateOrder = cfg.stateOrder,
            alphaCutoff = cfg.alphaCutoff,
            rowEmptyThreshold = cfg.rowEmptyThreshold,
            colEmptyThreshold = cfg.colEmptyThreshold,
            size = cfg.size or 35,
            pixelPerfect = cfg.pixelPerfect
        }
    }
end

return Player
