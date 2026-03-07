-- Player lifecycle wrapper for create/reset/update/draw operations.
local PlayerEntity = require("src/entities/player")

local PlayerSystem = {}

local player = nil

function PlayerSystem.ensure(context, playWidth, playHeight)
    if player then
        return player
    end

    local cfg = context or {}
    player = PlayerEntity.new({
        x = (playWidth or 0) / 2,
        y = (playHeight or 0) / 2,
        speed = cfg.playerSpeed or 300,
        moveStartSpeed = cfg.playerMoveStartSpeed,
        moveRampDuration = cfg.playerMoveRampDuration,
        dashSpeed = cfg.playerDashSpeed,
        dashDuration = cfg.playerDashDuration,
        dashCooldown = cfg.playerDashCooldown,
        dashEnergyCost = cfg.playerDashEnergyCost,
        dashSoundPath = cfg.dashSoundPath,
        size = cfg.playerSize or 35,
        spritePath = cfg.playerSpritePath or "assets/sprites/player/Robot.png",
        frameDuration = cfg.playerFrameDuration or 0.12,
        animMode = cfg.playerAnimMode,
        frameWidth = cfg.playerFrameWidth,
        frameHeight = cfg.playerFrameHeight,
        frameCols = cfg.playerFrameCols,
        frameRows = cfg.playerFrameRows,
        frameLeft = cfg.playerFrameLeft,
        frameTop = cfg.playerFrameTop,
        frameSpacing = cfg.playerFrameSpacing,
        defaultAnim = cfg.playerDefaultAnim,
        stateFrameCounts = cfg.playerStateFrameCounts,
        stateFrameDurations = cfg.playerStateFrameDurations,
        stateRows = cfg.playerStateRows,
        maxHealth = cfg.playerMaxHealth or 100,
        health = cfg.playerHealth or 100,
        maxEnergy = cfg.playerMaxEnergy or 100,
        energy = cfg.playerEnergy or 100
    })

    return player
end

function PlayerSystem.resetForRun(context, playWidth, playHeight)
    local cfg = context or {}
    local p = PlayerSystem.ensure(cfg, playWidth, playHeight)
    p.x = (playWidth or 0) / 2
    p.y = (playHeight or 0) / 2
    p.frameIndex = 1
    p.frameTimer = 0
    p.health = p.maxHealth or (cfg.playerMaxHealth or 100)
    p.energy = p.maxEnergy or (cfg.playerMaxEnergy or 100)
    p.invulTimer = 0
    p.invulnerable = false
    p.hitThisFrame = false
    return p
end

function PlayerSystem.get()
    return player
end

function PlayerSystem.updateAnimation(dt)
    if not player then
        return
    end
    PlayerEntity.update(player, dt)
end

function PlayerSystem.draw()
    if not player then
        return
    end
    PlayerEntity.draw(player)
end

return PlayerSystem
