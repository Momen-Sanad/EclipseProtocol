-- Energy-cell entity helpers: spawn and render behavior with shared sprite caching.
local CollisionSystem = require("src/systems/collision_system")

local EnergyCell = {}

local spriteCache = {}
local DEFAULT_SPRITE_PATH = "assets/ui/Cell.png"
local DEFAULT_CELL_SIZE = 150

local function computeOpaqueBounds(path, fallbackW, fallbackH)
    if not (love and love.image and love.image.newImageData) then
        return { x = 0, y = 0, width = fallbackW, height = fallbackH }
    end

    local ok, imageData = pcall(love.image.newImageData, path)
    if not ok or not imageData then
        return { x = 0, y = 0, width = fallbackW, height = fallbackH }
    end

    local w, h = imageData:getDimensions()
    local minX, minY, maxX, maxY = nil, nil, nil, nil
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = imageData:getPixel(x, y)
            if (a or 0) > 0 then
                if not minX or x < minX then
                    minX = x
                end
                if not minY or y < minY then
                    minY = y
                end
                if not maxX or x > maxX then
                    maxX = x
                end
                if not maxY or y > maxY then
                    maxY = y
                end
            end
        end
    end

    if minX == nil or minY == nil or maxX == nil or maxY == nil then
        return { x = 0, y = 0, width = fallbackW, height = fallbackH }
    end

    return {
        x = minX,
        y = minY,
        width = math.max(1, (maxX - minX) + 1),
        height = math.max(1, (maxY - minY) + 1)
    }
end

local function ensureSprite(path)
    -- Reuse one loaded image across all cells to avoid reloading texture data every frame.
    local nextPath = path or DEFAULT_SPRITE_PATH
    local cached = spriteCache[nextPath]
    if cached then
        return cached
    end

    if not (love and love.graphics and love.graphics.newImage) then
        return nil
    end

    local ok, image = pcall(love.graphics.newImage, nextPath)
    if not ok or not image then
        return nil
    end

    local sourceWidth = image:getWidth()
    local sourceHeight = image:getHeight()
    local opaqueBounds = computeOpaqueBounds(nextPath, sourceWidth, sourceHeight)
    local entry = {
        image = image,
        sourceWidth = sourceWidth,
        sourceHeight = sourceHeight,
        opaqueBounds = opaqueBounds
    }
    spriteCache[nextPath] = entry
    return entry
end

function EnergyCell.new(opts)
    -- Build one cell table with sane defaults so callers can pass only what they need.
    opts = opts or {}
    local path = opts.spritePath or DEFAULT_SPRITE_PATH
    -- Cell sizes are forced to whole numbers and clamped to at least 1 pixel.
    local width = math.max(1, math.floor(opts.width or opts.size or DEFAULT_CELL_SIZE))
    local height = math.max(1, math.floor(opts.height or opts.size or DEFAULT_CELL_SIZE))
    local displaySize = math.max(width, height)
    local hitboxOffsetX = 0
    local hitboxOffsetY = 0
    local hitboxWidth = width
    local hitboxHeight = height

    local spriteEntry = ensureSprite(path)
    if spriteEntry and spriteEntry.opaqueBounds then
        local sourceMax = math.max(spriteEntry.sourceWidth or 1, spriteEntry.sourceHeight or 1)
        local scale = displaySize / sourceMax
        local bounds = spriteEntry.opaqueBounds
        hitboxOffsetX = (bounds.x or 0) * scale
        hitboxOffsetY = (bounds.y or 0) * scale
        hitboxWidth = math.max(1, (bounds.width or 1) * scale)
        hitboxHeight = math.max(1, (bounds.height or 1) * scale)
    end

    return {
        x = opts.x or 0,
        y = opts.y or 0,
        width = width,
        height = height,
        spritePath = path,
        hitboxOffsetX = hitboxOffsetX,
        hitboxOffsetY = hitboxOffsetY,
        hitboxWidth = hitboxWidth,
        hitboxHeight = hitboxHeight
    }
end

function EnergyCell.spawnRandom(playWidth, playHeight, size, opts)
    -- Spawn a cell fully inside the play area by limiting random range to (area - cell size).
    opts = opts or {}
    local w = playWidth or 0
    local h = playHeight or 0
    local cellSize = math.max(1, math.floor(size or opts.size or DEFAULT_CELL_SIZE))
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

function EnergyCell.collect(player, cells, playerSize)
    -- Returns how many cells were picked up this frame.
    if not player or not cells then
        return 0
    end

    -- Player hitbox is treated as a square of `playerSize`.
    local size = playerSize or 35
    local collected = 0
    -- Reverse iteration allows safe table.remove without skipping entries.
    for i = #cells, 1, -1 do
        local cell = cells[i]
        local cellX = (cell.x or 0) + (cell.hitboxOffsetX or 0)
        local cellY = (cell.y or 0) + (cell.hitboxOffsetY or 0)
        local cellW = cell.hitboxWidth or cell.width or 0
        local cellH = cell.hitboxHeight or cell.height or 0
        if CollisionSystem.overlaps(player.x, player.y, size, size, cellX, cellY, cellW, cellH) then
            table.remove(cells, i)
            collected = collected + 1
        end
    end
    return collected
end

function EnergyCell.draw(cell)
    -- Draw one cell sprite if available, otherwise draw a colored rectangle fallback.
    if not cell then
        return
    end

    local spriteEntry = ensureSprite(cell.spritePath)
    if spriteEntry and spriteEntry.image then
        -- Scale so the sprite's longest side matches the target cell size (keeps aspect ratio).
        local targetSize = math.max(cell.width or 1, cell.height or 1)
        local scale = targetSize / math.max(spriteEntry.sourceWidth or 1, spriteEntry.sourceHeight or 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(spriteEntry.image, cell.x, cell.y, 0, scale, scale)
        return
    end

    love.graphics.setColor(0.7, 0.9, 1.0, 1)
    love.graphics.rectangle("fill", cell.x, cell.y, cell.width or 1, cell.height or 1)
end

return EnergyCell
