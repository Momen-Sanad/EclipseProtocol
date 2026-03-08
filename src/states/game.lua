-- Main gameplay state: orchestrates systems for movement, AI, pickups, objectives, and HUD.
local InputSystem = require("src/systems/input_system")
local AbilitySystem = require("src/systems/ability_system")
local MovementSystem = require("src/systems/movement_system")
local AudioSystem = require("src/systems/audio_system")
local EnemyBase = require("src/entities/enemy_base")
local PlayfieldSystem = require("src/systems/playfield_system")
local PlayerSystem = require("src/systems/player_system")
local EnemySystem = require("src/systems/enemy_system")
local CellSystem = require("src/systems/cell_system")
local PowerNodeSystem = require("src/systems/power_node_system")
local EnergySystem = require("src/systems/energy_system")
local ScreenFlashSystem = require("src/systems/screen_flash_system")
local Hud = require("src/ui/hud")
local Kinematics = require("src/utils/kinematics")
local StateManager = require("src/core/state_manager")

local GameState = {}

local elapsedTime = 0
local DEFAULT_CELL_COUNT = 10
local DEFAULT_CELL_SIZE = 300
local DEFAULT_CELL_ENERGY_RESTORE = 25
local DEFAULT_DRONE_SIZE = 90
local DEFAULT_HUNTER_SIZE = 90
local DEFAULT_DAMAGE_FLASH_COLOR = { 1.0, 0.15, 0.15 }
local DEFAULT_DAMAGE_FLASH_ALPHA = 0.35
local DEFAULT_DAMAGE_FLASH_DURATION = 0.12

local function getPlayAreaSize(context)
    return PlayfieldSystem.getPlayAreaSize(
        (context and context.windowWidth) or 1280,
        (context and context.windowHeight) or 720
    )
end

local function ensureRuntime(context)
    local w, h = getPlayAreaSize(context)
    local player = PlayerSystem.ensure(context, w, h)
    return player, w, h
end

local function resetRun(context)
    local player, w, h = ensureRuntime(context)
    PlayerSystem.resetForRun(context, w, h)
    ScreenFlashSystem.reset()
    elapsedTime = 0

    CellSystem.reset(w, h, {
        count = context.cellCount or DEFAULT_CELL_COUNT,
        size = context.cellSize or DEFAULT_CELL_SIZE,
        spritePath = context.cellSpritePath or "assets/ui/Cell.png"
    })
    EnemySystem.reset(w, h, {
        droneSize = context.droneSize or DEFAULT_DRONE_SIZE,
        hunterSize = context.hunterSize or DEFAULT_HUNTER_SIZE
    })
    PowerNodeSystem.reset(w, h, context)
    AbilitySystem.reset(context)

    return player
end

function GameState.preload(context)
    -- Used by transition.lua so the destination state can prepare assets off-screen.
    PlayfieldSystem.ensureBackground((context and context.backgroundPath) or "assets/ui/background.png")
    ensureRuntime(context)
end

function GameState.enter(context, prevName)
    -- Reset transient gameplay state unless we are resuming from pause.
    PlayfieldSystem.ensureBackground((context and context.backgroundPath) or "assets/ui/background.png")
    local player = ensureRuntime(context)

    if prevName ~= "pause" then
        player = resetRun(context)
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
    PlayfieldSystem.ensureBackground((context and context.backgroundPath) or "assets/ui/background.png")
    local player, w, h = ensureRuntime(context)
    local playerSize = context.playerSize or 35

    ScreenFlashSystem.update(dt)
    player.hitThisFrame = false
    EnemyBase.updatePlayerInvul(player, dt)
    Kinematics.capturePreviousPosition(player)

    local bounds = {
        minX = 8,
        minY = 8,
        maxX = w - playerSize,
        maxY = h - playerSize
    }

    MovementSystem.update(player, InputSystem, dt, bounds)
    AbilitySystem.update(player, EnemySystem.getDrones(), EnemySystem.getHunters(), InputSystem, dt, playerSize)
    EnemySystem.update(player, dt, playerSize)

    -- Resolve node solidity before and after enemy/player collision exchange.
    PowerNodeSystem.resolveObstacleCollisions(player, playerSize, EnemySystem.getDrones(), EnemySystem.getHunters())
    EnemySystem.resolvePlayerCollisions(player, playerSize)
    PowerNodeSystem.resolveObstacleCollisions(player, playerSize, EnemySystem.getDrones(), EnemySystem.getHunters())
    if player.hitThisFrame then
        ScreenFlashSystem.trigger(
            context.damageFlashColor or DEFAULT_DAMAGE_FLASH_COLOR,
            context.damageFlashAlpha or DEFAULT_DAMAGE_FLASH_ALPHA,
            context.damageFlashDuration or DEFAULT_DAMAGE_FLASH_DURATION
        )
    end

    Kinematics.clampPosition(player, bounds)

    if player.health and player.health <= 0 then
        StateManager.change("transition", "gameover")
        return
    end

    if PowerNodeSystem.update(player, playerSize, InputSystem, dt) then
        StateManager.change("transition", "victory")
        return
    end

    PlayerSystem.updateAnimation(dt)
    InputSystem.update()
    elapsedTime = elapsedTime + dt

    local collected = CellSystem.collect(player, playerSize)
    if collected > 0 then
        EnergySystem.restoreFromCells(
            player,
            collected,
            context.energyCellRestore or DEFAULT_CELL_ENERGY_RESTORE
        )
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
    PlayfieldSystem.drawBackground((context and context.backgroundPath) or "assets/ui/background.png")
    local player = PlayerSystem.get()
    local playerSize = context.playerSize or 35

    EnemySystem.draw(player, playerSize)
    PlayerSystem.draw()
    AbilitySystem.draw()
    PowerNodeSystem.draw()
    CellSystem.draw()

    local promptText = PowerNodeSystem.getPrompt(player, playerSize)
    if promptText then
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        love.graphics.setColor(0.9, 0.96, 1.0, 0.95)
        local textW = love.graphics.getFont():getWidth(promptText)
        love.graphics.print(promptText, (w - textW) / 2, h - 56)
    end

    Hud.draw(player, elapsedTime, CellSystem.getCollectedTotal())
    ScreenFlashSystem.draw()
end

function GameState.exit()
    ScreenFlashSystem.reset()
end

return GameState
