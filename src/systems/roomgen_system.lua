-- Coordinates per-room entity generation using shared context and difficulty scaling.
local CellSystem = require("src/systems/cell_system")
local EnemySystem = require("src/systems/enemy_system")
local PowerNodeSystem = require("src/systems/power_node_system")

local RoomgenSystem = {}

local DEFAULT_CELL_COUNT = 10
local DEFAULT_CELL_SIZE = 300
local DEFAULT_DRONE_SIZE = 90
local DEFAULT_HUNTER_SIZE = 90
local DEFAULT_PATROL_NODE_MIN_DISTANCE = 260
local DEFAULT_POWER_NODE_PATROL_PADDING = 16

function RoomgenSystem.setupRoom(context, playWidth, playHeight, difficulty, preserveCells)
    -- Rebuild entities/objectives for the current room using difficulty-scaled values.
    local cfg = context or {}
    local scaled = difficulty or {}
    local w = playWidth or 0
    local h = playHeight or 0

    CellSystem.reset(w, h, {
        count = scaled.cellCount or cfg.cellCount or DEFAULT_CELL_COUNT,
        size = cfg.cellSize or DEFAULT_CELL_SIZE,
        spritePath = cfg.cellSpritePath or "assets/ui/Cell.png",
        minGap = cfg.cellMinGap,
        preserveCollectedTotal = preserveCells and true or false
    })

    EnemySystem.resetPatrols(w, h, {
        droneSize = cfg.droneSize or DEFAULT_DRONE_SIZE,
        patrolCount = scaled.patrolCount,
        patrolDamage = scaled.patrolDamage,
        patrolMinDistanceToNode = cfg.patrolMinDistanceToNode or DEFAULT_PATROL_NODE_MIN_DISTANCE
    })

    PowerNodeSystem.reset(w, h, {
        powerNodeSize = cfg.powerNodeSize,
        powerNodeCount = scaled.powerNodeCount or cfg.powerNodeCount,
        powerNodeInteractRange = cfg.powerNodeInteractRange,
        powerNodeRepairDuration = cfg.powerNodeRepairDuration,
        powerNodeMinSpacing = cfg.powerNodeMinSpacing,
        patrolLanes = EnemySystem.getPatrolLanes(),
        patrolLanePadding = cfg.powerNodePatrolPadding or DEFAULT_POWER_NODE_PATROL_PADDING
    })

    EnemySystem.resetHunters(w, h, {
        hunterSize = cfg.hunterSize or DEFAULT_HUNTER_SIZE,
        hunterCount = scaled.hunterCount,
        hunterDamage = scaled.hunterDamage,
        repairNodes = PowerNodeSystem.getNodes()
    })
end

return RoomgenSystem
