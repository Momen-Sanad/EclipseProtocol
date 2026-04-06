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
local ScoreSystem = require("src/systems/score_system")
local SpawnSystem = require("src/systems/spawn_system")
local RoomgenSystem = require("src/systems/roomgen_system")
local ProgressionSystem = require("src/systems/progression_system")
local EvacuationSystem = require("src/systems/evacuation_system")
local DoorSystem = require("src/systems/door_system")
local ScreenFlashSystem = require("src/systems/screen_flash_system")
local VfxSystem = require("src/systems/vfx_system")
local RoomFrameSystem = require("src/systems/room_frame_system")
local Hud = require("src/ui/hud")
local Kinematics = require("src/utils/kinematics")
local UrgencyUtils = require("src/utils/urgency_utils")
local StateManager = require("src/core/state_manager")
local World = require("src/world/world")
local Events = require("src/core/events")
local DoorTrigger = require("src/world/door_trigger")

local PlayState = {}

local DEFAULT_CELL_ENERGY_RESTORE = 25
local DEFAULT_DAMAGE_FLASH_COLOR = { 1.0, 0.15, 0.15 }
local DEFAULT_DAMAGE_FLASH_ALPHA = 0.35
local DEFAULT_DAMAGE_FLASH_DURATION = 0.12
local DEFAULT_EVAC_WARNING_START_SECONDS = 60
local DEFAULT_EVAC_WARNING_MAX_PITCH_SCALE = 1.32
local DEFAULT_PLAYFIELD_COLOR = { 0.12, 0.20, 0.36, 1.0 }

local world = nil
local unpackArgs = (table and table.unpack) or unpack

local function computeEvacuationAudioScale(context)
    if EvacuationSystem.getState() ~= EvacuationSystem.STATES.ACTIVE then
        return 1.0
    end

    local startSeconds = math.max(1, (context and context.evacuationWarningStartSeconds) or DEFAULT_EVAC_WARNING_START_SECONDS)
    local progress, inWindow = UrgencyUtils.windowProgress(EvacuationSystem.getTimeRemaining(), startSeconds)
    if not inWindow then
        return 1.0
    end

    -- Smooth urgency ramp: subtle at first, stronger as timer approaches zero.
    local eased = UrgencyUtils.smoothstep01(progress)
    local maxScale = math.max(1.0, (context and context.evacuationWarningMaxPitchScale) or DEFAULT_EVAC_WARNING_MAX_PITCH_SCALE)
    return 1.0 + ((maxScale - 1.0) * eased)
end

local function getEvacuationStatus()
    return {
        timeRemaining = EvacuationSystem.getTimeRemaining(),
        phaseLabel = EvacuationSystem.getPhaseLabel()
    }
end

local function getTopOverlayBottom()
    -- Keeps the centered run-status text below any top-edge door or evac zone.
    local occupiedBottom = 0
    local doors = DoorSystem.getDoors()
    local doorList = { doors and doors.entry or nil, doors and doors.exit or nil }

    for _, door in ipairs(doorList) do
        if door and door.edge == "top" then
            occupiedBottom = math.max(occupiedBottom, (door.y or 0) + (door.height or 0))
        end
    end

    local zone = EvacuationSystem.getEscapeZone()
    if zone and (zone.y or 0) <= 0 then
        occupiedBottom = math.max(occupiedBottom, (zone.y or 0) + (zone.height or 0))
    end

    return occupiedBottom
end

local function drawCenteredChip(text, y, palette)
    if not text or text == "" then
        return
    end

    local w = love.graphics.getWidth()
    local font = love.graphics.getFont()
    local padX = 18
    local boxH = font:getHeight() + 16
    local boxW = math.min(w - 120, font:getWidth(text) + (padX * 2))
    local boxX = math.floor((w - boxW) * 0.5)
    local boxY = math.floor(y)
    local col = palette or {}
    local fill = col.fill or { 0.08, 0.12, 0.18, 0.82 }
    local edge = col.edge or { 0.48, 0.60, 0.78, 0.92 }
    local glow = col.glow or { 0.52, 0.74, 0.98, 0.12 }
    local textCol = col.text or { 0.88, 0.94, 1.0, 0.96 }

    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 8, 8)
    love.graphics.setColor(glow)
    love.graphics.rectangle("fill", boxX + 12, boxY + 7, boxW - 24, 3, 2, 2)
    love.graphics.setColor(edge)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 8, 8)

    local textX = math.floor(boxX + ((boxW - font:getWidth(text)) * 0.5))
    local textY = math.floor(boxY + ((boxH - font:getHeight()) * 0.5))
    love.graphics.setColor(0.02, 0.04, 0.08, 0.95)
    love.graphics.print(text, textX + 1, textY + 1)
    love.graphics.setColor(textCol)
    love.graphics.print(text, textX, textY)
end

local function getPlayAreaSize(context)
    -- Uses the live viewport size with context fallback.
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

    local currentRoom = RoomgenSystem.getCurrentRoom()
    if currentRoom then
        world.room.index = currentRoom.index or ((world.progression.roomsCleared or 0) + 1)
        world.room.bounds = currentRoom.bounds or world.room.bounds
        world.room.last = (currentRoom.doors and currentRoom.doors.exit == nil) and true or false
        world.room.data = currentRoom
    else
        world.room.index = (world.progression.roomsCleared or 0) + 1
        local roomsToEscape = world.progression.roomsToEscape or 0
        world.room.last = roomsToEscape > 0 and world.room.index >= roomsToEscape
    end
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

local function storeRunSummary(context, result)
    if not context then
        return
    end

    context.runSummary = ScoreSystem.buildRunSummary(result, {
        elapsedTime = ProgressionSystem.getElapsedTime(),
        cellsCollected = CellSystem.getCollectedTotal(),
        roomsCleared = ProgressionSystem.getRoomsCleared(),
        roomsToEscape = ProgressionSystem.getRoomsToEscape()
    }, context)
end

local function isCurrentRoomLast()
    return (ProgressionSystem.getRoomsCleared() + 1) >= ProgressionSystem.getRoomsToEscape()
end

local function configureRoomDoors(context, playWidth, playHeight, room)
    local roomDoors = (room and room.doors) or {}
    DoorSystem.setupRoom(playWidth, playHeight, {
        hasEntryDoor = roomDoors.entry ~= nil,
        hasExitDoor = roomDoors.exit ~= nil,
        entryDoor = roomDoors.entry,
        exitDoor = roomDoors.exit,
        doorEdgeMargin = context and context.doorEdgeMargin,
        doorThickness = context and context.doorThickness,
        doorWidthFactor = context and context.doorWidthFactor,
        doorHeightFactor = context and context.doorHeightFactor,
        doorEvacZonePadding = context and context.doorEvacZonePadding,
        evacuationZoneWidthFactor = context and context.evacuationZoneWidthFactor,
        evacuationZoneHeight = context and context.evacuationZoneHeight,
        evacuationZoneTop = context and context.evacuationZoneTop
    })
    DoorSystem.setExitOpen(false)
end

local function placePlayerForRoom(player, room, playWidth, playHeight, playerSize)
    local spawn = (room and room.spawn) or {}
    SpawnSystem.placePlayerInSafeSpawn(
        player,
        playWidth,
        playHeight,
        playerSize,
        spawn.player,
        {
            preferredSpawn = spawn.entryPoint or spawn.playerAnchor,
            entryDoor = room and room.doors and room.doors.entry or nil
        }
    )
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
            StateManager.change(payload.name, unpackArgs(args))
            return true
        end

        if event.name == "room_transition" then
            local payload = event.payload or {}
            local room = RoomgenSystem.setupRoom(
                context,
                playWidth,
                playHeight,
                ProgressionSystem.getDifficulty(),
                true,
                {
                    entryDoor = payload.entryDoor,
                    roomsCleared = ProgressionSystem.getRoomsCleared(),
                    roomsToEscape = ProgressionSystem.getRoomsToEscape()
                }
            )
            configureRoomDoors(context, playWidth, playHeight, room)
            placePlayerForRoom(player, room, playWidth, playHeight, playerSize)
        end
    end

    return false
end

local function resetRun(context)
    -- Full run reset: player, pickups, enemies, objectives, abilities, and timers.
    if context then
        context.runSummary = nil
    end
    local _, w, h = ensureWorld(context)
    if world and world.events then
        world.events:clear()
    end

    local difficulty = ProgressionSystem.beginRunWorld(world, context)
    EvacuationSystem.beginRun(difficulty)

    local player = PlayerSystem.reset(world, ProgressionSystem.buildPlayerResetConfig(context, difficulty), w, h)
    local playerSize = (player and player.hitboxSize) or (context and context.playerSize) or 35
    ScreenFlashSystem.reset()
    VfxSystem.reset()
    AudioSystem.setGlobalPlaybackScale(1.0)
    EvacuationSystem.configureEscapeZone(w, h)

    local room = RoomgenSystem.setupRoom(
        context,
        w,
        h,
        difficulty,
        false,
        {
            resetMap = true,
            roomsCleared = ProgressionSystem.getRoomsCleared(),
            roomsToEscape = ProgressionSystem.getRoomsToEscape()
        }
    )
    configureRoomDoors(context, w, h, room)
    placePlayerForRoom(player, room, w, h, playerSize)
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
    PlayfieldSystem.ensureBackground()
    ensureRuntime(context)
end

function PlayState.enter(context, prevName)
    -- Reset transient gameplay state unless we are resuming from pause.
    PlayfieldSystem.ensureBackground()
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
    PlayfieldSystem.ensureBackground()
    local player, w, h = ensureRuntime(context)
    local playerSize = (player and player.hitboxSize) or context.playerSize or 35
    EvacuationSystem.configureEscapeZone(w, h)

    -- Phase 1: global objectives/timers.
    local evacuationResult = EvacuationSystem.update(dt)
    AudioSystem.setGlobalPlaybackScale(computeEvacuationAudioScale(context))
    if evacuationResult == EvacuationSystem.STATES.FAILED then
        storeRunSummary(context, "gameover")
        queueStateChange("transition", "gameover")
        if handleQueuedEvents(context, w, h, player, playerSize) then
            return
        end
    end

    -- Phase 2: input -> ability -> movement -> AI intent application.
    ScreenFlashSystem.update(dt)
    VfxSystem.update(dt)
    player.hitThisFrame = false
    HealthSystem.ensureValid(player)
    DamageSystem.updatePlayerInvulnerability(player, dt)
    EnergySystem.update(player, dt, context.energyRegenRate or 0)
    Kinematics.capturePreviousPosition(player)

    local activeRoom = RoomgenSystem.getCurrentRoom()
    local roomBounds = activeRoom and activeRoom.bounds or nil
    local roomMinX = roomBounds and roomBounds.minX or 8
    local roomMinY = roomBounds and roomBounds.minY or 8
    local roomMaxX = roomBounds and roomBounds.maxX or (w - 8)
    local roomMaxY = roomBounds and roomBounds.maxY or (h - 8)

    local bounds = {
        minX = roomMinX,
        minY = roomMinY,
        maxX = math.max(roomMinX, roomMaxX - playerSize),
        maxY = math.max(roomMinY, roomMaxY - playerSize)
    }

    local worldBounds = {
        minX = roomMinX,
        minY = roomMinY,
        maxX = roomMaxX,
        maxY = roomMaxY
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
        storeRunSummary(context, "gameover")
        queueStateChange("transition", "gameover")
        if handleQueuedEvents(context, w, h, player, playerSize) then
            return
        end
    end

    if EvacuationSystem.tryComplete(player, playerSize, InputSystem) then
        storeRunSummary(context, "victory")
        queueStateChange("transition", "victory")
        if handleQueuedEvents(context, w, h, player, playerSize) then
            return
        end
    end

    -- Phase 4: progression/room flow.
    if not EvacuationSystem.isEvacuationActive() then
        local nodesRepaired, repairCanceled = PowerNodeSystem.update(player, playerSize, InputSystem, dt)
        if repairCanceled then
            VfxSystem.spawnRepairFailHint(player, playerSize)
        end
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
            local room = RoomgenSystem.getCurrentRoom()
            local exitTrigger = room and room.doorTriggers and room.doorTriggers.exit or nil
            local touchedDoorTrigger = DoorTrigger.playerTouchesTrigger(exitTrigger, player, playerSize)
            if nodesRepaired and touchedDoorTrigger and DoorSystem.tryUseExit(player, playerSize, InputSystem) then
                local nextEntryDoor = DoorSystem.getExitDoor()
                world.events:push("door_touched", {
                    door = nextEntryDoor
                })
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

    -- Re-apply on active sources started outside AudioSystem helpers (for example looping footsteps).
    AudioSystem.refreshGlobalPlaybackScale()

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
    PlayfieldSystem.drawBackground((context and context.playfieldColor) or DEFAULT_PLAYFIELD_COLOR)
    local player = PlayerSystem.get()
    local playerSize = (player and player.hitboxSize) or context.playerSize or 35
    local room = RoomgenSystem.getCurrentRoom()

    RoomFrameSystem.draw(
        room and room.bounds or nil,
        DoorSystem.getDoors(),
        context
    )

    EnemySystem.draw(player, playerSize)
    DoorSystem.draw()
    EvacuationSystem.draw()
    PlayerSystem.draw()
    if player and context and context.showHudDebug then
        love.graphics.setColor(1.0, 0.2, 0.2, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", player.x or 0, player.y or 0, playerSize, playerSize)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
    AbilitySystem.draw()
    PowerNodeSystem.draw()
    CellSystem.draw()
    VfxSystem.draw()

    local promptText = EvacuationSystem.getPrompt(player, playerSize)
    if not promptText then
        promptText = DoorSystem.getPrompt(player, playerSize)
    end
    if not promptText then
        promptText = PowerNodeSystem.getPrompt(player, playerSize)
    end
    if promptText then
        local drawH = love.graphics.getHeight()
        drawCenteredChip(
            promptText,
            drawH - 62,
            {
                fill = { 0.08, 0.12, 0.18, 0.86 },
                edge = { 0.48, 0.80, 0.96, 0.92 },
                glow = { 0.45, 0.82, 0.98, 0.14 },
                text = { 0.90, 0.97, 1.0, 0.98 }
            }
        )
    end

    local evacuation = getEvacuationStatus()
    Hud.draw(
        player,
        ProgressionSystem.getElapsedTime(),
        CellSystem.getCollectedTotal(),
        {
            timeRemaining = evacuation.timeRemaining,
            timerLabel = EvacuationSystem.isEvacuationActive() and "EVAC" or "TIMER",
            timerColor = EvacuationSystem.isEvacuationActive()
                and { 0.84, 0.96, 1.0, 1.0 }
                or { 0.78, 0.86, 0.94, 1.0 },
            showDebug = context and context.showHudDebug
        }
    )

    local statusY = math.max(74, getTopOverlayBottom() + 18)
    drawCenteredChip(
        ProgressionSystem.getStatusLine(evacuation),
        statusY,
        {
            fill = { 0.08, 0.12, 0.18, 0.78 },
            edge = { 0.42, 0.56, 0.74, 0.9 },
            glow = { 0.40, 0.64, 0.90, 0.10 },
            text = { 0.84, 0.92, 0.98, 0.96 }
        }
    )

    if EvacuationSystem.getState() == EvacuationSystem.STATES.ACTIVE then
        ScreenFlashSystem.drawEvacuationWarning(
            EvacuationSystem.getTimeRemaining(),
            {
                startSeconds = (context and context.evacuationWarningStartSeconds) or 60
            }
        )
    end

    ScreenFlashSystem.draw()
end

function PlayState.exit()
    -- Defensive cleanup for effects that should not leak into other states.
    AudioSystem.setGlobalPlaybackScale(1.0)
    ScreenFlashSystem.reset()
end

return PlayState
