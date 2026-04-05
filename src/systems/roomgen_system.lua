-- Coordinates per-room entity generation using shared context and difficulty scaling.
local CellSystem = require("src/systems/cell_system")
local EnemySystem = require("src/systems/enemy_system")
local PowerNodeSystem = require("src/systems/power_node_system")
local SpawnSystem = require("src/systems/spawn_system")
local Map = require("src/world/map")

local RoomgenSystem = {}

local DEFAULT_CELL_COUNT = 10
local DEFAULT_CELL_SIZE = 300
local DEFAULT_DRONE_SIZE = 90
local DEFAULT_HUNTER_SIZE = 90
local DEFAULT_PATROL_NODE_MIN_DISTANCE = 260
local DEFAULT_POWER_NODE_PATROL_PADDING = 16

local activeMap = nil
local currentRoom = nil

local function getRunSeed(context)
    local cfg = context or {}
    return cfg.roomSeed or cfg.mapSeed or cfg.worldSeed or os.time()
end

local function ensureMap(context, playWidth, playHeight, opts)
    local options = opts or {}
    if options.resetMap or not activeMap then
        activeMap = Map.new({
            seed = getRunSeed(context),
            width = playWidth,
            height = playHeight
        })
        currentRoom = nil
    end
    return activeMap
end

local function populateHostilesAndNodes(cfg, scaled, w, h, spawn, entrySpawn, playerSpawnSize, protectedSpawnZone)
    EnemySystem.resetPatrols(w, h, {
        droneSize = cfg.droneSize or DEFAULT_DRONE_SIZE,
        patrolCount = scaled.patrolCount,
        patrolDamage = scaled.patrolDamage,
        patrolMinDistanceToNode = cfg.patrolMinDistanceToNode or DEFAULT_PATROL_NODE_MIN_DISTANCE,
        patrolSpawnBounds = spawn.patrol,
        playerSpawn = entrySpawn,
        playerSpawnSize = playerSpawnSize
    })

    PowerNodeSystem.reset(w, h, {
        powerNodeSize = cfg.powerNodeSize,
        powerNodeCount = scaled.powerNodeCount or cfg.powerNodeCount,
        powerNodeInteractRange = cfg.powerNodeInteractRange,
        powerNodeRepairDuration = cfg.powerNodeRepairDuration,
        powerNodeMinSpacing = cfg.powerNodeMinSpacing,
        patrolLanes = EnemySystem.getPatrolLanes(),
        patrolLanePadding = cfg.powerNodePatrolPadding or DEFAULT_POWER_NODE_PATROL_PADDING,
        spawnBounds = spawn.nodes,
        protectedZones = protectedSpawnZone and { protectedSpawnZone } or nil
    })

    EnemySystem.resetHunters(w, h, {
        hunterSize = cfg.hunterSize or DEFAULT_HUNTER_SIZE,
        hunterCount = scaled.hunterCount,
        hunterDamage = scaled.hunterDamage,
        repairNodes = PowerNodeSystem.getNodes(),
        hunterSpawnBounds = spawn.hunters,
        playerSpawn = entrySpawn,
        playerSpawnSize = playerSpawnSize
    })
end

function RoomgenSystem.setupRoom(context, playWidth, playHeight, difficulty, preserveCells, opts)
    -- Rebuild entities/objectives for the generated room using difficulty-scaled values.
    local options = opts or {}
    local cfg = context or {}
    local scaled = difficulty or {}
    local w = playWidth or 0
    local h = playHeight or 0
    local map = ensureMap(context, w, h, options)

    currentRoom = Map.nextRoom(map, {
        width = w,
        height = h,
        entryDoor = options.entryDoor,
        roomsCleared = options.roomsCleared or 0,
        roomsToEscape = options.roomsToEscape or 1,
        context = cfg
    })

    local spawn = (currentRoom and currentRoom.spawn) or {}
    local entrySpawn = spawn.entryPoint
    local playerSpawnSize = (entrySpawn and entrySpawn.size) or cfg.playerSize or 35
    local protectedSpawnZone = nil
    if entrySpawn then
        protectedSpawnZone = {
            x = entrySpawn.x,
            y = entrySpawn.y,
            width = playerSpawnSize,
            height = playerSpawnSize
        }
    end

    CellSystem.reset(w, h, {
        count = scaled.cellCount or cfg.cellCount or DEFAULT_CELL_COUNT,
        size = cfg.cellSize or DEFAULT_CELL_SIZE,
        spritePath = cfg.cellSpritePath or "assets/ui/Cell.png",
        minGap = cfg.cellMinGap,
        preserveCollectedTotal = preserveCells and true or false,
        spawnBounds = spawn.cells
    })

    if entrySpawn then
        -- Keep retrying until this exact transition entry spawn remains safe.
        while true do
            populateHostilesAndNodes(cfg, scaled, w, h, spawn, entrySpawn, playerSpawnSize, protectedSpawnZone)
            if SpawnSystem.isSafePlayerSpawn(entrySpawn.x, entrySpawn.y, playerSpawnSize) then
                break
            end
        end
    else
        populateHostilesAndNodes(cfg, scaled, w, h, spawn, entrySpawn, playerSpawnSize, protectedSpawnZone)
    end

    return currentRoom
end

function RoomgenSystem.getCurrentRoom()
    return currentRoom
end

function RoomgenSystem.getMap()
    return activeMap
end

return RoomgenSystem
