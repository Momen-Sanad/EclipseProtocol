-- Main gameplay state: orchestrates systems for movement, AI, pickups, objectives, and HUD.
local InputSystem = require("src/systems/input_system")
local AbilitySystem = require("src/systems/ability_system")
local MovementSystem = require("src/systems/movement_system")
local AudioSystem = require("src/systems/audio_system")
local DamageSystem = require("src/systems/damage_system")
local HealthSystem = require("src/systems/health_system")
local PlayfieldSystem = require("src/systems/playfield_system")
local PlayerSystem = require("src/systems/player_system")
local EnemySystem = require("src/systems/enemy_system")
local CellSystem = require("src/systems/cell_system")
local PowerNodeSystem = require("src/systems/power_node_system")
local EnergySystem = require("src/systems/energy_system")
local SpawnSystem = require("src/systems/spawn_system")
local RoomgenSystem = require("src/systems/roomgen_system")
local ProgressionSystem = require("src/systems/progression_system")
local ScreenFlashSystem = require("src/systems/screen_flash_system")
local Hud = require("src/ui/hud")
local Kinematics = require("src/utils/kinematics")
local StateManager = require("src/core/state_manager")

local GameState = {}

local DEFAULT_CELL_ENERGY_RESTORE = 25
local DEFAULT_DAMAGE_FLASH_COLOR = { 1.0, 0.15, 0.15 }
local DEFAULT_DAMAGE_FLASH_ALPHA = 0.35
local DEFAULT_DAMAGE_FLASH_DURATION = 0.12

local function getPlayAreaSize(context)
    -- Uses live background-scaled viewport size with context fallback.
    return PlayfieldSystem.getPlayAreaSize(
        (context and context.windowWidth) or 1280,
        (context and context.windowHeight) or 720
    )
end

local function ensureRuntime(context)
    -- Ensures player exists and returns current play area metrics.
    local w, h = getPlayAreaSize(context)
    local player = PlayerSystem.ensure(context, w, h)
    return player, w, h
end

local function resetRun(context)
    -- Full run reset: player, pickups, enemies, objectives, abilities, and timers.
    local difficulty = ProgressionSystem.beginRun(context)

    local _, w, h = ensureRuntime(context)
    local playerSize = (context and context.playerSize) or 35
    local player = PlayerSystem.resetForRun(ProgressionSystem.buildPlayerResetConfig(context, difficulty), w, h)
    ScreenFlashSystem.reset()

    RoomgenSystem.setupRoom(context, w, h, difficulty, false)
    SpawnSystem.placePlayerInSafeSpawn(player, w, h, playerSize)
    AbilitySystem.reset(ProgressionSystem.buildAbilityConfig(context, difficulty))

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
    ensureRuntime(context)

    if prevName ~= "pause" then
        resetRun(context)
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
    -- Update order matters: invulnerability/resources, abilities, movement, collisions, then HUD-facing data.
    PlayfieldSystem.ensureBackground((context and context.backgroundPath) or "assets/ui/background.png")
    local player, w, h = ensureRuntime(context)
    local playerSize = context.playerSize or 35

    ScreenFlashSystem.update(dt)
    player.hitThisFrame = false
    HealthSystem.ensureValid(player)
    DamageSystem.updatePlayerInvulnerability(player, dt)
    EnergySystem.update(player, dt, context.energyRegenRate or 0)
    Kinematics.capturePreviousPosition(player)

    local bounds = {
        minX = 8,
        minY = 8,
        maxX = w - playerSize,
        maxY = h - playerSize
    }

    AbilitySystem.update(player, EnemySystem.getDrones(), EnemySystem.getHunters(), InputSystem, dt, playerSize)
    MovementSystem.update(player, InputSystem, dt, bounds)
    EnemySystem.update(player, dt, playerSize)

    -- Resolve node solidity before and after enemy/player collision exchange.
    PowerNodeSystem.resolveObstacleCollisions(player, playerSize, EnemySystem.getDrones(), EnemySystem.getHunters())
    local hitEvents = EnemySystem.resolvePlayerCollisions(player, playerSize)
    local healthRequests = DamageSystem.processPlayerEnemyContacts(player, hitEvents, playerSize)
    HealthSystem.applyRequests(player, healthRequests)
    PowerNodeSystem.resolveObstacleCollisions(player, playerSize, EnemySystem.getDrones(), EnemySystem.getHunters())
    if player.hitThisFrame then
        ScreenFlashSystem.trigger(
            context.damageFlashColor or DEFAULT_DAMAGE_FLASH_COLOR,
            context.damageFlashAlpha or DEFAULT_DAMAGE_FLASH_ALPHA,
            context.damageFlashDuration or DEFAULT_DAMAGE_FLASH_DURATION
        )
    end

    Kinematics.clampPosition(player, bounds)

    if HealthSystem.isDead(player) then
        StateManager.change("transition", "gameover")
        return
    end

    if PowerNodeSystem.update(player, playerSize, InputSystem, dt) then
        if ProgressionSystem.advanceRoom() then
            StateManager.change("transition", "victory")
            return
        end

        -- Advance to next room while preserving run stats and resources.
        RoomgenSystem.setupRoom(context, w, h, ProgressionSystem.getDifficulty(), true)
        SpawnSystem.placePlayerInSafeSpawn(player, w, h, playerSize)
        InputSystem.update()
        return
    end

    PlayerSystem.updateAnimation(dt)
    InputSystem.update()
    ProgressionSystem.addElapsedTime(dt)

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
    -- Escape pauses; all other keys route to input buffering.
    if key == "escape" then
        StateManager.change("pause")
        return
    end
    InputSystem.keypressed(key)
end

function GameState.keyreleased(key)
    -- Forward release events so movement axes and one-shot inputs clear correctly.
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

    Hud.draw(player, ProgressionSystem.getElapsedTime(), CellSystem.getCollectedTotal())

    local status = ProgressionSystem.getStatusLine()
    local statusW = love.graphics.getFont():getWidth(status)
    love.graphics.setColor(0.86, 0.93, 0.98, 0.95)
    love.graphics.print(status, (love.graphics.getWidth() - statusW) / 2, 20)

    ScreenFlashSystem.draw()
end

function GameState.exit()
    -- Defensive cleanup for effects that should not leak into other states.
    ScreenFlashSystem.reset()
end

return GameState
