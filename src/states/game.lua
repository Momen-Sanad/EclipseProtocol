local InputSystem = require("src/systems/input_system")
local MovementSystem = require("src/systems/movement_system")
local AudioSystem = require("src/systems/audio_system")
local PlayerEntity = require("src/entities/player")
local Hud = require("src/ui/hud")
local StateManager = require("src/core/state_manager")

local GameState = {}

local loaded = false
local BG = nil
local BG_SCALE = 1
local BG_OFFSET_X = 0
local BG_OFFSET_Y = 0
local windowWidth = 0
local windowHeight = 0

local Player = nil

local function loadAssets(context)
    if loaded then
        return
    end

    windowWidth = context.windowWidth or 1280
    windowHeight = context.windowHeight or 720

    BG = love.graphics.newImage(context.backgroundPath or "assets/background.png")
    local bgW = BG:getWidth()
    local bgH = BG:getHeight()
    BG_SCALE = math.max(windowWidth / bgW, windowHeight / bgH)
    BG_OFFSET_X = (windowWidth - bgW * BG_SCALE) / 2
    BG_OFFSET_Y = (windowHeight - bgH * BG_SCALE) / 2

    loaded = true
end

local function ensurePlayer(context)
    if Player then
        return
    end

    Player = PlayerEntity.new({
        x = (context.windowWidth or 1280) / 2,
        y = (context.windowHeight or 720) / 2,
        speed = context.playerSpeed or 300,
        dashSpeed = context.playerDashSpeed,
        dashDuration = context.playerDashDuration,
        dashCooldown = context.playerDashCooldown,
        size = context.playerSize or 35,
        spritePath = context.playerSpritePath or "assets/sprites/player/Robot.png",
        frameDuration = context.playerFrameDuration or 0.12,
        animMode = context.playerAnimMode,
        frameWidth = context.playerFrameWidth,
        frameHeight = context.playerFrameHeight,
        frameCols = context.playerFrameCols,
        frameRows = context.playerFrameRows,
        frameLeft = context.playerFrameLeft,
        frameTop = context.playerFrameTop,
        frameSpacing = context.playerFrameSpacing,
        defaultAnim = context.playerDefaultAnim,
        stateFrameCounts = context.playerStateFrameCounts,
        stateFrameDurations = context.playerStateFrameDurations,
        stateRows = context.playerStateRows,
        maxHealth = context.playerMaxHealth or 100,
        health = context.playerHealth or 100,
        maxEnergy = context.playerMaxEnergy or 100,
        energy = context.playerEnergy or 100
    })
end

function GameState.preload(context)
    loadAssets(context)
    ensurePlayer(context)
end

function GameState.enter(context, prevName)
    loadAssets(context)
    ensurePlayer(context)
    if prevName ~= "pause" then
        Player.x = (context.windowWidth or windowWidth) / 2
        Player.y = (context.windowHeight or windowHeight) / 2
        Player.frameIndex = 1
        Player.frameTimer = 0
    end

    if prevName == "gameover" then
        if context.gameMusicPath and context.gameMusicPath ~= "" then
            AudioSystem.playMusic(context.gameMusicPath)
        else
            AudioSystem.stopMusic()
        end
    end

    if InputSystem.keysHeld then
        InputSystem.keysHeld = {}
        InputSystem.keysPressed = {}
    end
end

function GameState.update(dt, context)
    if not Player then
        ensurePlayer(context)
    end

    MovementSystem.update(
        Player,
        InputSystem,
        dt,
        {
            minX = 8,
            minY = 8,
            maxX = (context.windowWidth or windowWidth) - (context.playerSize or 35),
            maxY = (context.windowHeight or windowHeight) - (context.playerSize or 35)
        }
    )

    PlayerEntity.update(Player, dt)
    InputSystem.update()
end

function GameState.keypressed(key)
    if key == "escape" then
        StateManager.change("pause")
        return
    end
    InputSystem.keypressed(key)
end

function GameState.keyreleased(key)
    InputSystem.keyreleased(key)
end

function GameState.draw(context)
    loadAssets(context)
    ensurePlayer(context)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(BG, BG_OFFSET_X, BG_OFFSET_Y, 0, BG_SCALE, BG_SCALE)
    PlayerEntity.draw(Player)
    Hud.draw(Player)
end

return GameState
