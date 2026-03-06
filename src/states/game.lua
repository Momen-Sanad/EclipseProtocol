local InputSystem = require("src/systems/input_system")
local MovementSystem = require("src/systems/movement_system")
local CollisionSystem = require("src/systems/collision_system")
local AudioSystem = require("src/systems/audio_system")
local PlayerEntity = require("src/entities/player")
local EnemyBase = require("src/entities/enemy_base")
local PatrolDrone = require("src/entities/patrol_drone")
local HunterDrone = require("src/entities/hunter_drone")
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
local elapsedTime = 0
local Cells = {}
local CellsCollected = 0
local CELL_COUNT = 10
local CELL_SIZE = 300
local CellSprite = nil
local Drones = {}
local DRONE_SIZE = 90
local Hunters = {}
local HUNTER_SIZE = 90

local function ensureCellSprite()
    if CellSprite then
        return
    end
    CellSprite = love.graphics.newImage("assets/ui/Cell.png")
end

local function spawnCell(context)
    local w = context.windowWidth or windowWidth
    local h = context.windowHeight or windowHeight
    local cell = {
        x = love.math.random(0, math.max(0, w - CELL_SIZE)),
        y = love.math.random(0, math.max(0, h - CELL_SIZE)),
        width = CELL_SIZE,
        height = CELL_SIZE
    }
    table.insert(Cells, cell)
end

local function resetCells(context)
    Cells = {}
    CellsCollected = 0
    for _ = 1, CELL_COUNT do
        spawnCell(context)
    end
end

local function resetDrones(context)
    Drones = {}
    Hunters = {}

    local w = context.windowWidth or windowWidth or 1280
    local h = context.windowHeight or windowHeight or 720
    local margin = DRONE_SIZE + 40

    local x1 = margin
    local y1 = math.floor(h * 0.3)
    local x2 = math.max(margin, w - margin)
    local y2 = y1

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
        color = { 0.95, 0.4, 0.25, 1.0 }
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
        color = { 0.2, 0.85, 1.0, 1.0 },
        coneColor = { 0.2, 0.8, 1.0, 0.18 },
        lineColor = { 0.9, 0.9, 1.0, 0.7 },
        lookColor = { 0.2, 0.9, 1.0, 0.9 }
    })

    table.insert(Hunters, hunter)
end

local function loadAssets(context)
    if loaded then
        return
    end

    windowWidth = context.windowWidth or 1280
    windowHeight = context.windowHeight or 720

    BG = love.graphics.newImage(context.backgroundPath or "assets/ui/background.png")
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
        dashSoundPath = context.dashSoundPath,
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
        Player.health = Player.maxHealth or (context.playerMaxHealth or 100)
        Player.energy = Player.maxEnergy or (context.playerMaxEnergy or 100)
        Player.invulTimer = 0
        Player.invulnerable = false
        Player.hitThisFrame = false
        elapsedTime = 0
        ensureCellSprite()
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
    if not Player then
        ensurePlayer(context)
    end
    Player.hitThisFrame = false
    EnemyBase.updatePlayerInvul(Player, dt)
    Player.prevX = Player.x
    Player.prevY = Player.y

    local bounds = {
        minX = 8,
        minY = 8,
        maxX = (context.windowWidth or windowWidth) - (context.playerSize or 35),
        maxY = (context.windowHeight or windowHeight) - (context.playerSize or 35)
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
        local playerSize = context.playerSize or 35
        
        -- if CollisionSystem.playerEnemyOverlap(Player, drone, playerSize) then
        --     drone:onCollision(Player)
        -- end
    end

    for _, hunter in ipairs(Hunters) do
        local playerSize = context.playerSize or 35
        hunter.prevX = hunter.x
        hunter.prevY = hunter.y
        hunter:update(Player, dt, playerSize)
        
        -- if CollisionSystem.playerEnemyOverlap(Player, hunter, playerSize) then
        --     hunter:onCollision(Player)
        -- end
    end

    CollisionSystem.stopPlayerOnEnemies(Drones, Player, context.playerSize or 35)
    CollisionSystem.stopPlayerOnEnemies(Hunters, Player, context.playerSize or 35)
    CollisionSystem.stopEnemiesOnPlayer(Drones, Player, context.playerSize or 35)
    CollisionSystem.stopEnemiesOnPlayer(Hunters, Player, context.playerSize or 35)

    Player.x = math.max(bounds.minX, math.min(Player.x, bounds.maxX))
    Player.y = math.max(bounds.minY, math.min(Player.y, bounds.maxY))

    if Player.health and Player.health <= 0 then
        StateManager.change("transition", "gameover")
        return
    end

    PlayerEntity.update(Player, dt)
    InputSystem.update()

    elapsedTime = elapsedTime + dt

    local collected = CollisionSystem.collectCells(Player, Cells, context.playerSize or 35)
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
    loadAssets(context)
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
    for _, cell in ipairs(Cells) do
        if CellSprite then
            local scale = CELL_SIZE / math.max(CellSprite:getWidth(), CellSprite:getHeight())
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(CellSprite, cell.x, cell.y, 0, scale, scale)
        else
            love.graphics.setColor(0.7, 0.9, 1.0, 1)
            love.graphics.rectangle("fill", cell.x, cell.y, cell.width, cell.height)
        end
    end

    Hud.draw(Player, elapsedTime, CellsCollected)
end

return GameState
