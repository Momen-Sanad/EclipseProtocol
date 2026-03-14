-- Owns energy-cell spawn, collection, rendering, and score tracking.
local CollisionSystem = require("src/systems/collision_system")
local EnergyCell = require("src/entities/energy_cell")
local SearchUtils = require("src/utils/search_utils")

local CellSystem = {}

local cells = {}
local totalCollected = 0
local cellCount = 10
local cellSize = 300
local cellSpritePath = "assets/ui/Cell.png"
local cellMinGap = 20

local function overlapsWithGap(a, b, gap)
    -- Enforces a minimum edge gap between two axis-aligned rectangles.
    local pad = math.max(0, gap or 0)
    local ax = a.x or 0
    local ay = a.y or 0
    local aw = a.width or 0
    local ah = a.height or 0
    local bx = b.x or 0
    local by = b.y or 0
    local bw = b.width or 0
    local bh = b.height or 0

    return CollisionSystem.overlaps(
        ax, ay, aw + pad, ah + pad,
        bx, by, bw + pad, bh + pad
    )
end

local function hasSpawnConflict(candidate)
    for _, existing in ipairs(cells) do
        if overlapsWithGap(candidate, existing, cellMinGap) then
            return true
        end
    end
    return false
end

local function findFallbackSpawn(playWidth, playHeight)
    -- Deterministic coarse search fallback when random retries cannot find a valid slot.
    local maxX = math.max(0, (playWidth or 0) - cellSize)
    local maxY = math.max(0, (playHeight or 0) - cellSize)
    local step = math.max(8, math.floor(cellSize * 0.2))
    local x, y = SearchUtils.findGrid(
        { minX = 0, maxX = maxX, minY = 0, maxY = maxY },
        step,
        function(candidateX, candidateY)
            local candidate = EnergyCell.new({
                x = candidateX,
                y = candidateY,
                width = cellSize,
                height = cellSize,
                spritePath = cellSpritePath
            })
            return not hasSpawnConflict(candidate)
        end,
        { randomStart = true, wrap = true }
    )

    if x ~= nil and y ~= nil then
        return EnergyCell.new({
            x = x,
            y = y,
            width = cellSize,
            height = cellSize,
            spritePath = cellSpritePath
        })
    end

    return nil
end

local function spawnCell(playWidth, playHeight)
    -- Random spawn with retries + fallback scan to keep a minimum distance from existing cells.
    local maxAttempts = 120
    for _ = 1, maxAttempts do
        local candidate = EnergyCell.spawnRandom(playWidth, playHeight, cellSize, {
            spritePath = cellSpritePath
        })
        if not hasSpawnConflict(candidate) then
            cells[#cells + 1] = candidate
            return
        end
    end

    local fallback = findFallbackSpawn(playWidth, playHeight)
    if fallback then
        cells[#cells + 1] = fallback
        return
    end

    -- Last resort: place one anyway so game setup cannot deadlock on impossible packing.
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
    cellMinGap = math.max(0, math.floor(opts.minGap or opts.minDistance or 20))
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
