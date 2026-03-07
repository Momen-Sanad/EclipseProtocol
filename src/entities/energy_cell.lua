-- Energy-cell entity helpers: spawn and render behavior with shared sprite caching.
local EnergyCell = {}

local sprite = nil
local spritePath = nil
local DEFAULT_SPRITE_PATH = "assets/ui/Cell.png"

local function ensureSprite(path)
    local nextPath = path or DEFAULT_SPRITE_PATH
    if sprite and spritePath == nextPath then
        return sprite
    end

    sprite = love.graphics.newImage(nextPath)
    spritePath = nextPath
    return sprite
end

function EnergyCell.new(opts)
    opts = opts or {}
    local width = math.max(1, math.floor(opts.width or opts.size or 300))
    local height = math.max(1, math.floor(opts.height or opts.size or 300))
    return {
        x = opts.x or 0,
        y = opts.y or 0,
        width = width,
        height = height,
        spritePath = opts.spritePath or DEFAULT_SPRITE_PATH
    }
end

function EnergyCell.spawnRandom(playWidth, playHeight, size, opts)
    opts = opts or {}
    local w = playWidth or 0
    local h = playHeight or 0
    local cellSize = math.max(1, math.floor(size or opts.size or 300))
    local x = love.math.random(0, math.max(0, w - cellSize))
    local y = love.math.random(0, math.max(0, h - cellSize))

    return EnergyCell.new({
        x = x,
        y = y,
        width = cellSize,
        height = cellSize,
        spritePath = opts.spritePath
    })
end

function EnergyCell.draw(cell)
    if not cell then
        return
    end

    local img = ensureSprite(cell.spritePath)
    if img then
        local targetSize = math.max(cell.width or 1, cell.height or 1)
        local scale = targetSize / math.max(img:getWidth(), img:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, cell.x, cell.y, 0, scale, scale)
        return
    end

    love.graphics.setColor(0.7, 0.9, 1.0, 1)
    love.graphics.rectangle("fill", cell.x, cell.y, cell.width or 1, cell.height or 1)
end

return EnergyCell
