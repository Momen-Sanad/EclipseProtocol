-- Owns energy-cell spawn, collection, rendering, and score tracking.
local CollisionSystem = require("src/systems/collision_system")

local CellSystem = {}

local cells = {}
local totalCollected = 0
local cellCount = 10
local cellSize = 300
local sprite = nil
local spritePath = nil

local function ensureSprite(path)
    local nextPath = path or "assets/ui/Cell.png"
    if not sprite or spritePath ~= nextPath then
        sprite = love.graphics.newImage(nextPath)
        spritePath = nextPath
    end
end

local function spawnCell(playWidth, playHeight)
    local w = playWidth or 0
    local h = playHeight or 0
    cells[#cells + 1] = {
        x = love.math.random(0, math.max(0, w - cellSize)),
        y = love.math.random(0, math.max(0, h - cellSize)),
        width = cellSize,
        height = cellSize
    }
end

function CellSystem.reset(playWidth, playHeight, opts)
    opts = opts or {}
    cellCount = math.max(0, math.floor(opts.count or 10))
    cellSize = math.max(1, math.floor(opts.size or 300))
    totalCollected = 0
    cells = {}

    ensureSprite(opts.spritePath)
    for _ = 1, cellCount do
        spawnCell(playWidth, playHeight)
    end
end

function CellSystem.collect(player, playerSize)
    local collected = CollisionSystem.collectCells(player, cells, playerSize)
    if collected > 0 then
        totalCollected = totalCollected + collected
    end
    return collected
end

function CellSystem.getCollectedTotal()
    return totalCollected
end

function CellSystem.draw()
    for _, cell in ipairs(cells) do
        if sprite then
            local scale = cellSize / math.max(sprite:getWidth(), sprite:getHeight())
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sprite, cell.x, cell.y, 0, scale, scale)
        else
            love.graphics.setColor(0.7, 0.9, 1.0, 1)
            love.graphics.rectangle("fill", cell.x, cell.y, cell.width, cell.height)
        end
    end
end

return CellSystem
