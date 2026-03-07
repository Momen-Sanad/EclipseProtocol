-- Main gameplay state: owns the player, pickups, enemies, HUD, and win/lose flow.
local InputSystem = require("src/systems/input_system")
local MovementSystem = require("src/systems/movement_system")
local CollisionSystem = require("src/systems/collision_system")
local AudioSystem = require("src/systems/audio_system")
local PlayerEntity = require("src/entities/player")
local EnemyBase = require("src/entities/enemy_base")
local EnergyCell = require("src/entities/energy_cell")
local PatrolDrone = require("src/entities/patrol_drone")
local HunterDrone = require("src/entities/hunter_drone")
local Hud = require("src/ui/hud")
local Kinematics = require("src/utils/kinematics")
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
local elapsedTime = 0
local Cells = {}
local CellsCollected = 0
local CELL_COUNT = 10
local CELL_SIZE = 300
local PatrolDroneSprite = nil
local HunterDroneSprite = nil
local Drones = {}
local DRONE_SIZE = 90
local Hunters = {}
local HUNTER_SIZE = 90

local function refreshBackground()
    if not BG then
        return
    end

    local w, h = love.graphics.getDimensions()
    if w == windowWidth and h == windowHeight then
        return
    end

    windowWidth = w
    windowHeight = h

    local bgW = BG:getWidth()
    local bgH = BG:getHeight()
    BG_SCALE = math.max(windowWidth / bgW, windowHeight / bgH)
    BG_OFFSET_X = (windowWidth - bgW * BG_SCALE) / 2
    BG_OFFSET_Y = (windowHeight - bgH * BG_SCALE) / 2
end

local function getPlayAreaSize(context)
    refreshBackground()

    local w = windowWidth
    local h = windowHeight

    if w <= 0 or h <= 0 then
        w = (context and context.windowWidth) or 1920
        h = (context and context.windowHeight) or 1080
    end

    return w, h
end

local function ensurePatrolDroneSprite(context)
    if PatrolDroneSprite then
        return
    end

    local spritePath = (context and context.patrolDroneSpritePath) or "assets/sprites/player/Patrol Drone.png"
    if love.filesystem.getInfo(spritePath) then
        PatrolDroneSprite = love.graphics.newImage(spritePath)
        PatrolDroneSprite:setFilter("nearest", "nearest")
    end
end

local function ensureHunterDroneSprite(context)
    if HunterDroneSprite then
        return
    end

    local spritePath = (context and context.hunterDroneSpritePath) or "assets/sprites/player/Hunter Drone.png"
    if love.filesystem.getInfo(spritePath) then
        HunterDroneSprite = love.graphics.newImage(spritePath)
        HunterDroneSprite:setFilter("nearest", "nearest")
    end
end

local function resetCells(context)
    -- Called on fresh game starts to rebuild the pickup set from scratch.
    local w, h = getPlayAreaSize(context)
    local cellSize = (context and context.cellSize) or CELL_SIZE
    local cellPath = (context and context.cellSpritePath) or "assets/ui/Cell.png"
    Cells = EnergyCell.reset(CELL_COUNT, {
        playWidth = w,
        playHeight = h,
        size = cellSize,
        spritePath = cellPath
    })
    CellsCollected = 0
end

local function resetDrones(context)
    -- Spawns one patrol drone and one hunter drone using the current window size.
    Drones = {}
    Hunters = {}
    ensurePatrolDroneSprite(context)
    ensureHunterDroneSprite(context)

    local w, h = getPlayAreaSize(context)
    local margin = DRONE_SIZE + 40

    local x1 = margin
    local y1 = math.floor(h * 0.3)
    local x2 = math.max(margin, w - margin)
    local y2 = y1
    local patrolScale = 1
    local hunterScale = 1
    if PatrolDroneSprite then
        patrolScale = DRONE_SIZE / math.max(PatrolDroneSprite:getWidth(), PatrolDroneSprite:getHeight())
    end
    if HunterDroneSprite then
        hunterScale = HUNTER_SIZE / math.max(HunterDroneSprite:getWidth(), HunterDroneSprite:getHeight())
    end

    local drone = PatrolDrone.new({
        x = x1,
        y = y1,
        x1 = x1,
        y1 = y1,
        x2 = x2,
        y2 = y2,
        size = DRONE_SIZE,
        speed = 180,
        damage = 12,
        invulDuration = 1.5,
        sprite = PatrolDroneSprite,
        scale = patrolScale
    })

    table.insert(Drones, drone)

    local hunter = HunterDrone.new({
        x = math.floor(w * 0.2),
        y = math.floor(h * 0.7),
        size = HUNTER_SIZE,
        speed = 220,
        visionRange = 420,
        dotThreshold = 0.5,
        damage = 15,
        invulDuration = 1.5,
        sprite = HunterDroneSprite,
        scale = hunterScale,
        color = { 0.2, 0.85, 1.0, 1.0 },
        coneColor = { 0.2, 0.8, 1.0, 0.18 },
        lineColor = { 0.9, 0.9, 1.0, 0.7 },
        lookColor = { 0.2, 0.9, 1.0, 0.9 }
    })

    table.insert(Hunters, hunter)
end

local function loadAssets(context)
    -- Background sizing is cached because it is stable across one game session.
    if loaded then
        refreshBackground()
        return
    end

    BG = love.graphics.newImage(context.backgroundPath or "assets/ui/background.png")
    refreshBackground()
    loaded = true
end

local function ensurePlayer(context)
    -- The player instance is persistent between pause transitions and recreated only once.
    if Player then
        return
    end

    local w, h = getPlayAreaSize(context)

    Player = PlayerEntity.new({
        x = w / 2,
        y = h / 2,
        speed = context.playerSpeed or 300,
        moveStartSpeed = context.playerMoveStartSpeed,
        moveRampDuration = context.playerMoveRampDuration,
        dashSpeed = context.playerDashSpeed,
        dashDuration = context.playerDashDuration,
        dashCooldown = context.playerDashCooldown,
        -- Forward the shared audio path so player movement can play the dash cue.
        dashSoundPath = context.dashSoundPath,
        footstepSoundPath = context.footstepSoundPath,
        footstepInterval = context.footstepInterval,
        footstepVolume = context.footstepVolume,
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
    -- Used by transition.lua so the destination state can prepare assets off-screen.
    loadAssets(context)
    ensurePlayer(context)
end

function GameState.enter(context, prevName)
    -- Reset transient gameplay state unless we are resuming from pause.
    loadAssets(context)
    ensurePlayer(context)
    ensurePatrolDroneSprite(context)
    ensureHunterDroneSprite(context)
    local w, h = getPlayAreaSize(context)
    if prevName ~= "pause" then
        Player.x = w / 2
        Player.y = h / 2
        Player.frameIndex = 1
        Player.frameTimer = 0
        Player.health = Player.maxHealth or (context.playerMaxHealth or 100)
        Player.energy = Player.maxEnergy or (context.playerMaxEnergy or 100)
        Player.invulTimer = 0
        Player.invulnerable = false
        Player.hitThisFrame = false
        elapsedTime = 0
        resetCells(context)
        resetDrones(context)
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
    -- Update order matters: invulnerability, movement, enemies, collisions, then HUD-facing data.
    if not Player then
        ensurePlayer(context)
    end
    local w, h = getPlayAreaSize(context)
    Player.hitThisFrame = false
    EnemyBase.updatePlayerInvul(Player, dt)
    Kinematics.capturePreviousPosition(Player)

    local bounds = {
        minX = 8,
        minY = 8,
        maxX = w - (context.playerSize or 35),
        maxY = h - (context.playerSize or 35)
    }

    MovementSystem.update(
        Player,
        InputSystem,
        dt,
        bounds
    )

    for _, drone in ipairs(Drones) do
        drone.prevX = drone.x
        drone.prevY = drone.y
        drone:update(dt)
    end

    local playerSize = context.playerSize or 35
    for _, hunter in ipairs(Hunters) do
        hunter.prevX = hunter.x
        hunter.prevY = hunter.y
        hunter:update(Player, dt, playerSize)
    end

    CollisionSystem.stopPlayerOnEnemies(Drones, Player, context.playerSize or 35)
    CollisionSystem.stopPlayerOnEnemies(Hunters, Player, context.playerSize or 35)
    CollisionSystem.stopEnemiesOnPlayer(Drones, Player, context.playerSize or 35)
    CollisionSystem.stopEnemiesOnPlayer(Hunters, Player, context.playerSize or 35)

    -- Collision nudges can push the player outside bounds after movement integration.
    Kinematics.clampPosition(Player, bounds)

    if Player.health and Player.health <= 0 then
        StateManager.change("transition", "gameover")
        return
    end

    PlayerEntity.update(Player, dt)
    InputSystem.update()

    elapsedTime = elapsedTime + dt

    local collected = EnergyCell.collect(Player, Cells, context.playerSize or 35, {
        pickupSoundPath = (context and context.cellPickupSoundPath) or "assets/audio/sfx/Pickup.mp3"
    })
    if collected > 0 then
        CellsCollected = CellsCollected + collected
    end
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
    -- Render world layers back-to-front: background, enemies, player, pickups, HUD.
    loadAssets(context)
    refreshBackground()
    ensurePlayer(context)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(BG, BG_OFFSET_X, BG_OFFSET_Y, 0, BG_SCALE, BG_SCALE)
    for _, drone in ipairs(Drones) do
        drone:draw()
    end
    for _, hunter in ipairs(Hunters) do
        hunter:draw(Player, (context.playerSize or 35)/2)
    end
    PlayerEntity.draw(Player)
    EnergyCell.drawAll(Cells, {
        size = (context and context.cellSize) or CELL_SIZE,
        spritePath = (context and context.cellSpritePath) or "assets/ui/Cell.png"
    })

    Hud.draw(Player, elapsedTime, CellsCollected)
end

return GameState
