-- Owns energy-cell spawn, collection, rendering, and score tracking.
local CollisionSystem = require("src/systems/collision_system")
local EnergyCell = require("src/entities/energy_cell")

local CellSystem = {}

local cells = {}
local totalCollected = 0
local cellCount = 10
local cellSize = 300
local cellSpritePath = "assets/ui/Cell.png"

local function spawnCell(playWidth, playHeight)
    -- Helper for one randomized spawn respecting current size/sprite settings.
    cells[#cells + 1] = EnergyCell.spawnRandom(playWidth, playHeight, cellSize, {
        spritePath = cellSpritePath
    })
end

function CellSystem.reset(playWidth, playHeight, opts)
    -- Clears previous run cells and spawns a fresh batch.
    opts = opts or {}
    cellCount = math.max(0, math.floor(opts.count or 10))
    cellSize = math.max(1, math.floor(opts.size or 300))
    cellSpritePath = opts.spritePath or "assets/ui/Cell.png"
    if not opts.preserveCollectedTotal then
        totalCollected = 0
    end
    cells = {}

    for _ = 1, cellCount do
        spawnCell(playWidth, playHeight)
    end
end

function CellSystem.collect(player, playerSize)
    -- Removes overlapping cells and tracks total pickups for HUD/score.
    local collected = CollisionSystem.collectCells(player, cells, playerSize)
    if collected > 0 then
        totalCollected = totalCollected + collected
    end
    return collected
end

function CellSystem.getCollectedTotal()
    -- Lifetime counter for the current run.
    return totalCollected
end

function CellSystem.draw()
    -- Draws all live cells each frame.
    for _, cell in ipairs(cells) do
        EnergyCell.draw(cell)
    end
end

return CellSystem
