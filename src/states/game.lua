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
local DifficultySystem = require("src/systems/difficulty_system")
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
local DEFAULT_ROOMS_TO_ESCAPE = 3
local DEFAULT_PATROL_NODE_MIN_DISTANCE = 260
local DEFAULT_POWER_NODE_PATROL_PADDING = 16
local SAFE_SPAWN_PADDING = 12
local SAFE_SPAWN_RANDOM_ATTEMPTS = 140

local activeDifficulty = nil
local roomsCleared = 0
local roomsToEscape = DEFAULT_ROOMS_TO_ESCAPE

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

local function buildPlayerResetConfig(context, difficulty)
    -- Applies difficulty-scaled ability costs without mutating shared global context.
    local cfg = {}
    for key, value in pairs(context or {}) do
        cfg[key] = value
    end
    if difficulty then
        cfg.playerDashEnergyCost = difficulty.dashEnergyCost
    end
    return cfg
end

local function buildAbilityConfig(context, difficulty)
    -- Ability system receives scaled stun-gun cost plus shared base tuning.
    return {
        stunGunStunDuration = context.stunGunStunDuration,
        stunGunCooldown = context.stunGunCooldown,
        stunGunRange = context.stunGunRange,
        stunGunEnergyCost = difficulty and difficulty.stunGunEnergyCost or context.stunGunEnergyCost,
        stunGunLaserLifetime = context.stunGunLaserLifetime,
        stunGunSoundPath = context.stunGunSoundPath
    }
end

local function overlaps(aX, aY, aW, aH, bX, bY, bW, bH)
    return aX < bX + bW and bX < aX + aW and aY < bY + bH and bY < aY + aH
end

local function inHunterDetectionRange(x, y, playerSize, hunter)
    local px = x + (playerSize / 2)
    local py = y + (playerSize / 2)
    local hx = (hunter.x or 0) + ((hunter.width or 0) / 2)
    local hy = (hunter.y or 0) + ((hunter.height or 0) / 2)
    local dx = px - hx
    local dy = py - hy
    local distSq = (dx * dx) + (dy * dy)
    local range = math.max(0, hunter.visionRange or 0) + (playerSize * 0.35)
    return distSq <= (range * range)
end

local function inPatrolLine(x, y, playerSize, patrol)
    local playerCenterY = y + (playerSize / 2)
    local patrolCenterY = (patrol.y or 0) + ((patrol.height or 0) / 2)
    local lineBand = math.max(playerSize * 0.5, (patrol.height or playerSize) * 0.55)
    return math.abs(playerCenterY - patrolCenterY) <= lineBand
end

local function isSafePlayerSpawn(x, y, playerSize)
    local drones = EnemySystem.getDrones()
    local hunters = EnemySystem.getHunters()
    local nodes = PowerNodeSystem.getNodes()

    for _, hunter in ipairs(hunters) do
        if inHunterDetectionRange(x, y, playerSize, hunter) then
            return false
        end
    end

    for _, drone in ipairs(drones) do
        if inPatrolLine(x, y, playerSize, drone) then
            return false
        end
    end

    -- Also avoid immediate overlap with solid power nodes and enemy bodies.
    for _, node in ipairs(nodes) do
        if overlaps(x, y, playerSize, playerSize, node.x or 0, node.y or 0, node.width or 0, node.height or 0) then
            return false
        end
    end
    for _, drone in ipairs(drones) do
        if overlaps(x, y, playerSize, playerSize, drone.x or 0, drone.y or 0, drone.width or 0, drone.height or 0) then
            return false
        end
    end
    for _, hunter in ipairs(hunters) do
        if overlaps(x, y, playerSize, playerSize, hunter.x or 0, hunter.y or 0, hunter.width or 0, hunter.height or 0) then
            return false
        end
    end

    return true
end

local function findSafePlayerSpawn(w, h, playerSize)
    local minX = SAFE_SPAWN_PADDING
    local minY = SAFE_SPAWN_PADDING
    local maxX = math.max(minX, (w or 0) - playerSize - SAFE_SPAWN_PADDING)
    local maxY = math.max(minY, (h or 0) - playerSize - SAFE_SPAWN_PADDING)
    local centerX = math.floor(((w or 0) - playerSize) / 2)
    local centerY = math.floor(((h or 0) - playerSize) / 2)
    local rng = (love and love.math and love.math.random) or math.random

    if isSafePlayerSpawn(centerX, centerY, playerSize) then
        return centerX, centerY
    end

    for _ = 1, SAFE_SPAWN_RANDOM_ATTEMPTS do
        local x = rng(minX, maxX)
        local y = rng(minY, maxY)
        if isSafePlayerSpawn(x, y, playerSize) then
            return x, y
        end
    end

    local step = math.max(10, math.floor(playerSize * 0.75))
    for y = minY, maxY, step do
        for x = minX, maxX, step do
            if isSafePlayerSpawn(x, y, playerSize) then
                return x, y
            end
        end
    end

    return centerX, centerY
end

local function placePlayerInSafeSpawn(player, w, h, playerSize)
    local spawnX, spawnY = findSafePlayerSpawn(w, h, playerSize)
    player.x = spawnX
    player.y = spawnY
    Kinematics.stop(player)
end

local function setupRoom(context, w, h, difficulty, preserveCells)
    -- Rebuilds entities/objectives for the current room using difficulty-scaled values.
    local scaled = difficulty or {}
    CellSystem.reset(w, h, {
        count = scaled.cellCount or context.cellCount or DEFAULT_CELL_COUNT,
        size = context.cellSize or DEFAULT_CELL_SIZE,
        spritePath = context.cellSpritePath or "assets/ui/Cell.png",
        minGap = context.cellMinGap,
        preserveCollectedTotal = preserveCells and true or false
    })
    EnemySystem.resetPatrols(w, h, {
        droneSize = context.droneSize or DEFAULT_DRONE_SIZE,
        patrolCount = scaled.patrolCount,
        patrolDamage = scaled.patrolDamage,
        patrolMinDistanceToNode = context.patrolMinDistanceToNode or DEFAULT_PATROL_NODE_MIN_DISTANCE
    })

    PowerNodeSystem.reset(w, h, {
        powerNodeSize = context.powerNodeSize,
        powerNodeCount = scaled.powerNodeCount or context.powerNodeCount,
        powerNodeInteractRange = context.powerNodeInteractRange,
        powerNodeRepairDuration = context.powerNodeRepairDuration,
        powerNodeMinSpacing = context.powerNodeMinSpacing,
        patrolLanes = EnemySystem.getPatrolLanes(),
        patrolLanePadding = context.powerNodePatrolPadding or DEFAULT_POWER_NODE_PATROL_PADDING
    })

    EnemySystem.resetHunters(w, h, {
        hunterSize = context.hunterSize or DEFAULT_HUNTER_SIZE,
        hunterCount = scaled.hunterCount,
        hunterDamage = scaled.hunterDamage,
        repairNodes = PowerNodeSystem.getNodes()
    })
end

local function resetRun(context)
    -- Full run reset: player, pickups, enemies, objectives, abilities, and timers.
    activeDifficulty = DifficultySystem.buildRuntimeValues(context)
    roomsCleared = 0
    roomsToEscape = activeDifficulty.roomsToEscape or DEFAULT_ROOMS_TO_ESCAPE

    local _, w, h = ensureRuntime(context)
    local playerSize = (context and context.playerSize) or 35
    local player = PlayerSystem.resetForRun(buildPlayerResetConfig(context, activeDifficulty), w, h)
    ScreenFlashSystem.reset()
    elapsedTime = 0

    setupRoom(context, w, h, activeDifficulty, false)
    placePlayerInSafeSpawn(player, w, h, playerSize)
    AbilitySystem.reset(buildAbilityConfig(context, activeDifficulty))

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
        roomsCleared = roomsCleared + 1
        if roomsCleared >= roomsToEscape then
            StateManager.change("transition", "victory")
            return
        end

        -- Advance to next room while preserving run stats and resources.
        setupRoom(context, w, h, activeDifficulty, true)
        placePlayerInSafeSpawn(player, w, h, playerSize)
        InputSystem.update()
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

    Hud.draw(player, elapsedTime, CellSystem.getCollectedTotal())

    local roomProgress = ("ROOMS STABILIZED %d/%d"):format(roomsCleared, roomsToEscape)
    local diffLabel = (activeDifficulty and activeDifficulty.profileLabel) or "Medium"
    local status = roomProgress .. "  |  DIFFICULTY " .. string.upper(diffLabel)
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
