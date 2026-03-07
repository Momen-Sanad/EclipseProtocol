-- Energy cell pickup entity helpers (spawn, collect, and rendering).
local EnergyCell = {}
local AudioSystem = require("src/systems/audio_system")

local DEFAULT_SIZE = 300
local DEFAULT_SPRITE_PATH = "assets/ui/Cell.png"
local DEFAULT_PICKUP_SFX_PATH = "assets/audio/sfx/Pickup.mp3"
local DEFAULT_PICKUP_SFX_VOLUME = 0.35

local sprite = nil
local spritePath = nil

local function ensureSprite(path)
    local wantedPath = path or DEFAULT_SPRITE_PATH
    if sprite and spritePath == wantedPath then
        return sprite
    end

    sprite = nil
    spritePath = nil
    if love and love.filesystem and love.filesystem.getInfo(wantedPath) then
        sprite = love.graphics.newImage(wantedPath)
        sprite:setFilter("nearest", "nearest")
        spritePath = wantedPath
    end
    return sprite
end

local function overlaps(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

function EnergyCell.new(opts)
    local cfg = opts or {}
    local size = cfg.size or DEFAULT_SIZE
    local maxX = math.max(0, (cfg.playWidth or 0) - size)
    local maxY = math.max(0, (cfg.playHeight or 0) - size)
    return {
        x = love.math.random(0, maxX),
        y = love.math.random(0, maxY),
        width = size,
        height = size
    }
end

function EnergyCell.reset(count, opts)
    local cells = {}
    local total = math.max(0, math.floor(count or 0))
    for _ = 1, total do
        table.insert(cells, EnergyCell.new(opts))
    end
    return cells
end

function EnergyCell.collect(player, cells, playerSize, opts)
    if not player or not cells then
        return 0
    end

    local cfg = opts or {}
    local size = playerSize or 35
    local collected = 0
    for i = #cells, 1, -1 do
        local cell = cells[i]
        if overlaps(player.x, player.y, size, size, cell.x, cell.y, cell.width, cell.height) then
            table.remove(cells, i)
            collected = collected + 1
        end
    end

    if collected > 0 and not cfg.muteSfx then
        local soundPath = cfg.pickupSoundPath or DEFAULT_PICKUP_SFX_PATH
        local volume = cfg.pickupSoundVolume or DEFAULT_PICKUP_SFX_VOLUME
        AudioSystem.playSfx(soundPath, { volume = volume })
    end

    return collected
end

function EnergyCell.draw(cell, opts)
    if not cell then
        return
    end

    local cfg = opts or {}
    local image = ensureSprite(cfg.spritePath)
    if image then
        local drawSize = cfg.size or cell.width or DEFAULT_SIZE
        local scale = drawSize / math.max(image:getWidth(), image:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, cell.x, cell.y, 0, scale, scale)
        return
    end

    love.graphics.setColor(0.7, 0.9, 1.0, 1)
    love.graphics.rectangle("fill", cell.x, cell.y, cell.width, cell.height)
end

function EnergyCell.drawAll(cells, opts)
    if not cells then
        return
    end
    ensureSprite(opts and opts.spritePath)
    for _, cell in ipairs(cells) do
        EnergyCell.draw(cell, opts)
    end
end

return EnergyCell
