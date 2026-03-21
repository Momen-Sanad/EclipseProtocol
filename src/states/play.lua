-- Canonical play-state orchestrator built around shared world data + event queue.
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
local EvacuationSystem = require("src/systems/evacuation_system")
local DoorSystem = require("src/systems/door_system")
local ScreenFlashSystem = require("src/systems/screen_flash_system")
local Hud = require("src/ui/hud")
local Kinematics = require("src/utils/kinematics")
local StateManager = require("src/core/state_manager")
local World = require("src/world/world")
local Events = require("src/core/events")

local PlayState = {}

local DEFAULT_CELL_ENERGY_RESTORE = 25
local DEFAULT_DAMAGE_FLASH_COLOR = { 1.0, 0.15, 0.15 }
local DEFAULT_DAMAGE_FLASH_ALPHA = 0.35
local DEFAULT_DAMAGE_FLASH_DURATION = 0.12

local world = nil

local function getEvacuationStatus()
    return {
        timeRemaining = EvacuationSystem.getTimeRemaining(),
        phaseLabel = EvacuationSystem.getPhaseLabel()
    }
end

local function getPlayAreaSize(context)
    -- Uses live background-scaled viewport size with context fallback.
    return PlayfieldSystem.getPlayAreaSize(
        (context and context.windowWidth) or 1280,
        (context and context.windowHeight) or 720
    )
end

local function ensureWorld(context)
    local w, h = getPlayAreaSize(context)
    if not world then
        world = World.new(context, w, h)
        world.events = Events.new()
    else
        World.setContext(world, context)
    end

    world.size.width = w
    world.size.height = h
    world.room.bounds.minX = 8
    world.room.bounds.minY = 8
    world.room.bounds.maxX = math.max(8, w - 8)
    world.room.bounds.maxY = math.max(8, h - 8)

    return world, w, h
end

local function syncWorldSnapshot(player, playWidth, playHeight)
    if not world then
        return
    end

    world.player = player
    world.size.width = playWidth or world.size.width
    world.size.height = playHeight or world.size.height

    PlayerSystem.syncWorld(world)
    EnemySystem.syncWorld(world)
    CellSystem.syncWorld(world)
    PowerNodeSystem.syncWorld(world)
    DoorSystem.syncWorld(world)
    ProgressionSystem.syncWorld(world)
    EvacuationSystem.syncWorld(world)

    world.room.index = (world.progression.roomsCleared or 0) + 1
    local roomsToEscape = world.progression.roomsToEscape or 0
    world.room.last = roomsToEscape > 0 and world.room.index >= roomsToEscape
end

local function queueStateChange(stateName, ...)
    if not world or not world.events then
        return
    end
    world.events:push("state_change", {
        name = stateName,
        args = { ... }
    })
end

local function isCurrentRoomLast()
    return (ProgressionSystem.getRoomsCleared() + 1) >= ProgressionSystem.getRoomsToEscape()
end

local function configureRoomDoors(context, playWidth, playHeight, entryDoor)
    local roomsCleared = ProgressionSystem.getRoomsCleared()
    local roomsToEscape = ProgressionSystem.getRoomsToEscape()
    local currentRoomNumber = roomsCleared + 1
    local hasEntryDoor = currentRoomNumber > 1
    local hasExitDoor = currentRoomNumber < roomsToEscape

    DoorSystem.setupRoom(playWidth, playHeight, {
        hasEntryDoor = hasEntryDoor,
        hasExitDoor = hasExitDoor,
        entryDoor = entryDoor,
        doorEdgeMargin = context and context.doorEdgeMargin,
        doorThickness = context and context.doorThickness,
        doorWidthFactor = context and context.doorWidthFactor,
        doorHeightFactor = context and context.doorHeightFactor
    })
    DoorSystem.setExitOpen(false)
end

local function handleQueuedEvents(context, playWidth, playHeight, player, playerSize)
    if not world or not world.events then
        return false
    end

    local queue = world.events:drain()
    for _, event in ipairs(queue) do
        if event.name == "state_change" then
            local payload = event.payload or {}
            local args = payload.args or {}
            StateManager.change(payload.name, table.unpack(args))
            return true
        end

        if event.name == "room_transition" then
            local payload = event.payload or {}
            RoomgenSystem.setupRoom(context, playWidth, playHeight, ProgressionSystem.getDifficulty(), true)
            configureRoomDoors(context, playWidth, playHeight, payload.entryDoor)
            SpawnSystem.placePlayerInSafeSpawn(player, playWidth, playHeight, playerSize)
        end
    end

    return false
end

local function resetRun(context)
    -- Full run reset: player, pickups, enemies, objectives, abilities, and timers.
    local _, w, h = ensureWorld(context)
    if world and world.events then
        world.events:clear()
    end

    local difficulty = ProgressionSystem.beginRunWorld(world, context)
    EvacuationSystem.beginRun(difficulty)

    local playerSize = (context and context.playerSize) or 35
    local player = PlayerSystem.reset(world, ProgressionSystem.buildPlayerResetConfig(context, difficulty), w, h)
    ScreenFlashSystem.reset()
    EvacuationSystem.configureEscapeZone(w, h)

    RoomgenSystem.setupRoom(context, w, h, difficulty, false)
    configureRoomDoors(context, w, h, nil)
    SpawnSystem.placePlayerInSafeSpawn(player, w, h, playerSize)
    AbilitySystem.reset(ProgressionSystem.buildAbilityConfig(context, difficulty))

    syncWorldSnapshot(player, w, h)
    return player, w, h
end

local function ensureRuntime(context)
    -- Ensures world + player exist and returns current play-area metrics.
    local _, w, h = ensureWorld(context)
    local player = PlayerSystem.init(world, context, w, h)
    syncWorldSnapshot(player, w, h)
    return player, w, h
end

function PlayState.preload(context)
    -- Used by transition.lua so destination can preload assets off-screen.
    PlayfieldSystem.ensureBackground((context and context.backgroundPath) or "assets/ui/background.png")
    ensureRuntime(context)
end

function PlayState.enter(context, prevName)
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

function PlayState.update(dt, context)
    -- Phase 0: ensure world + runtime context.
    PlayfieldSystem.ensureBackground((context and context.backgroundPath) or "assets/ui/background.png")
    local player, w, h = ensureRuntime(context)
    local playerSize = context.playerSize or 35
    EvacuationSystem.configureEscapeZone(w, h)

    -- Phase 1: global objectives/timers.
    local evacuationResult = EvacuationSystem.update(dt)
    if evacuationResult == EvacuationSystem.STATES.FAILED then
        queueStateChange("transition", "gameover")
        if handleQueuedEvents(context, w, h, player, playerSize) then
            return
        end
    end

    -- Phase 2: input -> ability -> movement -> AI intent application.
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

    local worldBounds = {
        minX = 8,
        minY = 8,
        maxX = w - 8,
        maxY = h - 8
    }

    AbilitySystem.update(player, EnemySystem.getDrones(), EnemySystem.getHunters(), InputSystem, dt, playerSize)
    MovementSystem.update(player, InputSystem, dt, bounds)
    EnemySystem.update(player, dt, playerSize, worldBounds)

    -- Phase 3: collisions + damage/resource effects.
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
        queueStateChange("transition", "gameover")
        if handleQueuedEvents(context, w, h, player, playerSize) then
            return
        end
    end

    if EvacuationSystem.tryComplete(player, playerSize, InputSystem) then
        queueStateChange("transition", "victory")
        if handleQueuedEvents(context, w, h, player, playerSize) then
            return
        end
    end

    -- Phase 4: progression/room flow.
    if not EvacuationSystem.isEvacuationActive() then
        local nodesRepaired = PowerNodeSystem.update(player, playerSize, InputSystem, dt)
        local lastRoom = isCurrentRoomLast()

        if lastRoom then
            DoorSystem.setExitOpen(false)
            if nodesRepaired then
                world.events:push("room_cleared", {
                    roomsCleared = ProgressionSystem.getRoomsCleared() + 1
                })

                EvacuationSystem.onRoomCleared()
                if ProgressionSystem.advanceRoom() then
                    EvacuationSystem.startEvacuation()
                    world.events:push("evacuation_started", {
                        timeRemaining = EvacuationSystem.getTimeRemaining()
                    })
                    InputSystem.update()
                    syncWorldSnapshot(player, w, h)
                    handleQueuedEvents(context, w, h, player, playerSize)
                    return
                end
            end
        else
            DoorSystem.setExitOpen(nodesRepaired)
            if nodesRepaired and DoorSystem.tryUseExit(player, playerSize, InputSystem) then
                local nextEntryDoor = DoorSystem.getExitDoor()

                world.events:push("room_cleared", {
                    roomsCleared = ProgressionSystem.getRoomsCleared() + 1
                })

                EvacuationSystem.onRoomCleared()
                if ProgressionSystem.advanceRoom() then
                    DoorSystem.setExitOpen(false)
                    EvacuationSystem.startEvacuation()
                    world.events:push("evacuation_started", {
                        timeRemaining = EvacuationSystem.getTimeRemaining()
                    })
                else
                    world.events:push("room_transition", {
                        entryDoor = nextEntryDoor
                    })
                end

                InputSystem.update()
                syncWorldSnapshot(player, w, h)
                if handleQueuedEvents(context, w, h, player, playerSize) then
                    return
                end
            end
        end
    end

    -- Phase 5: post-simulation updates + metrics.
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
        world.events:push("cells_collected", { count = collected })
    end

    syncWorldSnapshot(player, w, h)
    handleQueuedEvents(context, w, h, player, playerSize)
end

function PlayState.keypressed(key)
    -- Escape pauses; all other keys route to input buffering.
    if key == "escape" then
        StateManager.change("pause")
        return
    end
    InputSystem.keypressed(key)
end

function PlayState.keyreleased(key)
    -- Forward release events so movement axes and one-shot inputs clear correctly.
    InputSystem.keyreleased(key)
end

function PlayState.draw(context)
    -- Render world layers back-to-front: background, enemies, doors, player, pickups, HUD.
    PlayfieldSystem.drawBackground((context and context.backgroundPath) or "assets/ui/background.png")
    local player = PlayerSystem.get()
    local playerSize = context.playerSize or 35

    EnemySystem.draw(player, playerSize)
    DoorSystem.draw()
    EvacuationSystem.draw()
    PlayerSystem.draw()
    AbilitySystem.draw()
    PowerNodeSystem.draw()
    CellSystem.draw()

    local promptText = EvacuationSystem.getPrompt(player, playerSize)
    if not promptText then
        promptText = DoorSystem.getPrompt(player, playerSize)
    end
    if not promptText then
        promptText = PowerNodeSystem.getPrompt(player, playerSize)
    end
    if promptText then
        local drawW = love.graphics.getWidth()
        local drawH = love.graphics.getHeight()
        love.graphics.setColor(0.9, 0.96, 1.0, 0.95)
        local textW = love.graphics.getFont():getWidth(promptText)
        love.graphics.print(promptText, (drawW - textW) / 2, drawH - 56)
    end

    Hud.draw(player, ProgressionSystem.getElapsedTime(), CellSystem.getCollectedTotal())

    local status = ProgressionSystem.getStatusLine(getEvacuationStatus())
    local statusW = love.graphics.getFont():getWidth(status)
    love.graphics.setColor(0.86, 0.93, 0.98, 0.95)
    love.graphics.print(status, (love.graphics.getWidth() - statusW) / 2, 20)

    ScreenFlashSystem.draw()
end

function PlayState.exit()
    -- Defensive cleanup for effects that should not leak into other states.
    ScreenFlashSystem.reset()
end

return PlayState
