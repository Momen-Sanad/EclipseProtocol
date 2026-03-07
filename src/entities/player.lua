--[[
    Player factory with flexible sprite / animation setup.

    Responsibilities:
      - Build player object with configurable movement/dash/health/energy
      - Support multiple animation pipelines:
          * "state" animations (named states: idle/run/dash) created either
            by scanning a sprite sheet for variable-sized frames or by using
            an Anim8 grid when frames are regular.
          * "directional" animations (up/down/left/right) using a regular grid.
          * fallback simple sprite-sheet frames produced by SpriteSheet.buildFrames.
      - Update animations (Anim8 or manual frame cycling)
      - Draw the player with proper centering and optional pixel-perfect rounding

    Important notes:
      - setupStateScanAnimation uses love.image.newImageData which is relatively
        expensive; if you call this repeatedly at runtime, cache the results.
      - Anim8 usage assumes Anim8 library API: newGrid, newAnimation, animation:update/draw/getFrame
      - Default asset paths are provided but are configurable via `config`
--]]

local SpriteSheet = require("src/utils/sprite_sheet")
local Anim8 = require("anim8.anim8")

local Player = {}

-- Helper: find the maximum numeric value in a table (useful for frame/grid inference)
local function maxKeyValue(tbl)
    local maxValue = 0
    if not tbl then
        return maxValue
    end
    for _, value in pairs(tbl) do
        if type(value) == "number" and value > maxValue then
            maxValue = value
        end
    end
    return maxValue
end

-- Helper: build a string range "1-N" for Anim8 grid calls
local function buildRange(count)
    return "1-" .. tostring(count)
end

-- Determine frameW/frameH if not given by the config.
-- Uses stateCounts (how many frames per state) and stateRows to infer the max columns/rows,
-- then divides the image dimensions to guess frame size.
-- Returns frameW, frameH (may be nil if not enough information).
local function ensureFrameSize(cfg, image, stateCounts, stateRows)
    local frameW = cfg.frameWidth
    local frameH = cfg.frameHeight

    -- Infer width from maximum number of columns specified in stateCounts
    if not frameW then
        local maxCols = maxKeyValue(stateCounts)
        if maxCols > 0 then
            frameW = image:getWidth() / maxCols
        end
    end

    -- Infer height from the number of rows implied by stateRows
    if not frameH then
        local rowCount = maxKeyValue(stateRows)
        if rowCount > 0 then
            frameH = image:getHeight() / rowCount
        end
    end

    return frameW, frameH
end

-- Build contiguous non-empty segments on an axis by scanning imageData rows or columns.
-- imageData: ImageData to scan
-- isRow: boolean - if true, we scan rows (find segments of non-empty horizontal bands),
--                 otherwise scan columns (vertical bands)
-- alphaCutoff: pixel alpha threshold to treat a pixel as transparent
-- emptyThreshold: fraction of transparent pixels in a line required to consider the line empty
--
-- Returns an array of {startIndex, endIndex} pairs describing runs of non-empty lines.
-- This is the low-level building block for the "state" auto-scan algorithm.
local function buildSegments(imageData, isRow, alphaCutoff, emptyThreshold)
    local w, h = imageData:getDimensions()
    local segments = {}
    local major = isRow and h or w     -- number of lines to iterate
    local minor = isRow and w or h     -- length of each line
    local start = nil

    for i = 0, major - 1 do
        local transparent = 0
        -- count transparent pixels along this line
        for j = 0, minor - 1 do
            local x = isRow and j or i
            local y = isRow and i or j
            local _, _, _, a = imageData:getPixel(x, y)
            if a <= alphaCutoff then
                transparent = transparent + 1
            end
        end

        local empty = (transparent / minor) >= emptyThreshold

        -- open segment when we encounter first non-empty line
        if not empty and start == nil then
            start = i
        -- close segment when an empty line follows a non-empty run
        elseif empty and start ~= nil then
            table.insert(segments, { start, i - 1 })
            start = nil
        end
    end

    -- if we ended while inside a segment, close it
    if start ~= nil then
        table.insert(segments, { start, major - 1 })
    end

    return segments
end

-- Given a row segment {yStart, yEnd}, find contiguous horizontal frame segments (columns)
-- inside that row band by scanning columns and testing per-column transparency across the row height.
-- Returns array of {xStart, xEnd} frame column ranges.
local function buildRowFrames(imageData, rowSeg, alphaCutoff, emptyThreshold)
    local w = imageData:getWidth()
    local frames = {}
    local rowHeight = rowSeg[2] - rowSeg[1] + 1
    local start = nil

    for x = 0, w - 1 do
        local transparent = 0
        for y = rowSeg[1], rowSeg[2] do
            local _, _, _, a = imageData:getPixel(x, y)
            if a <= alphaCutoff then
                transparent = transparent + 1
            end
        end

        local empty = (transparent / rowHeight) >= emptyThreshold

        if not empty and start == nil then
            start = x
        elseif empty and start ~= nil then
            table.insert(frames, { start, x - 1 })
            start = nil
        end
    end

    if start ~= nil then
        table.insert(frames, { start, w - 1 })
    end

    return frames
end

-- Build "state" animations by scanning a sprite sheet image for rows containing
-- animation states (idle/run/dash etc.) and columns that represent frames.
-- This is flexible and supports variable-sized frames and uneven spacings.
--
-- Algorithm overview:
-- 1. Load ImageData from spritePath (imageData lets us sample alpha per pixel).
-- 2. Scan rows for non-empty bands (buildSegments with isRow=true).
-- 3. For each state row, scan that band's columns for contiguous non-empty columns (buildRowFrames).
-- 4. Optionally trim or validate frame counts against expected counts (stateFrameCounts).
-- 5. For each detected column segment, create a Quad sized to the bounding box and register it with Anim8.
--
-- Returns true on success and sets player.sprite, player.animMode, player.animations, player.anim,
-- and scaling/frame size metadata on the player table. Returns false on failure so callers can fallback.
local function setupStateScanAnimation(player, cfg, image)
    local spritePath = cfg.spritePath or "assets/sprites/player/Robot.png"
    -- Note: newImageData reads pixel data into memory; expensive at runtime if repeated.
    local imageData = love.image.newImageData(spritePath)
    local imageW = imageData:getWidth()
    local imageH = imageData:getHeight()

    local alphaCutoff = cfg.alphaCutoff or 0.05         -- alpha threshold (0.0..1.0) for "transparent"
    local rowEmpty = cfg.rowEmptyThreshold or 0.98     -- fraction of transparent pixels to treat row as empty
    local colEmpty = cfg.colEmptyThreshold or 0.98     -- fraction for column emptiness

    -- Identify row bands that contain animation states (e.g., idle row, run row)
    local rowSegments = buildSegments(imageData, true, alphaCutoff, rowEmpty)
    if #rowSegments == 0 then
        return false
    end

    local stateOrder = cfg.stateOrder or { "idle", "run", "dash" }       -- sequence of states to scan
    local stateRows = cfg.stateRows or {}                                -- map stateName -> rowIndex (1-based)
    local stateCounts = cfg.stateFrameCounts or {}                       -- expected frames per state (optional)
    local durations = cfg.stateFrameDurations or {}                      -- per-state durations
    local defaultDuration = cfg.frameDuration or 0.12

    -- Track maximum frame size to compute scale that fits cfg.size
    local maxW, maxH = 0, 0
    player.sprite = image
    player.animMode = "state"
    player.animations = {}

    -- Iterate requested states in order and build animations
    for index, stateName in ipairs(stateOrder) do
        local rowIndex = stateRows[stateName] or index
        local rowSeg = rowSegments[rowIndex]
        if not rowSeg then
            -- missing row -> fail early so caller can fallback to other loader
            return false
        end

        -- find candidate frame columns inside that row band
        local colSegments = buildRowFrames(imageData, rowSeg, alphaCutoff, colEmpty)
        local expected = stateCounts[stateName]

        -- Validate frame counts if expected values are provided
        if expected and #colSegments < expected then
            return false
        end
        if #colSegments == 0 then
            return false
        end

        -- If more columns were detected than expected, trim to expected (prefer leftmost frames)
        if expected and #colSegments > expected then
            local trimmed = {}
            for i = 1, expected do
                trimmed[#trimmed + 1] = colSegments[i]
            end
            colSegments = trimmed
        end

        -- Build Anim8 frames from the column segments
        local frames = {}
        for _, colSeg in ipairs(colSegments) do
            local x = colSeg[1]
            local y = rowSeg[1]
            local w = colSeg[2] - colSeg[1] + 1
            local h = rowSeg[2] - rowSeg[1] + 1
            local quad = love.graphics.newQuad(x, y, w, h, imageW, imageH)
            frames[#frames + 1] = { quad = quad, w = w, h = h }
            if w > maxW then maxW = w end
            if h > maxH then maxH = h end
        end

        local duration = durations[stateName] or defaultDuration
        player.animations[stateName] = Anim8.newAnimation(frames, duration)
    end

    -- Default active animation
    player.anim = player.animations.idle or player.animations.run or player.animations.dash

    -- Compute scale so configured size fits the largest detected frame dimension
    local baseSize = math.max(1, math.max(maxW, maxH))
    local size = cfg.size or 35
    player.scale = size / baseSize
    player.frameW = maxW
    player.frameH = maxH
    player.pixelPerfect = cfg.pixelPerfect ~= false

    return true
end

-- Setup a grid-based animation pipeline using Anim8.newGrid or fallback directional frames.
-- Supports animMode == "state" (three named states) or "directional" (up/down/left/right).
-- When "state" and state-scanning fails, it falls back to grid-based frames using cfg.frameWidth/Height.
local function setupGridAnimation(player, cfg)
    -- Load the image as a regular Image (not ImageData); set nearest filter for crisp pixel art.
    local image = love.graphics.newImage(cfg.spritePath or "assets/sprites/player/Robot.png")
    image:setFilter("nearest", "nearest")
    local animMode = cfg.animMode or "directional"

    -- state-mode using regular grid fallback
    if animMode == "state" then
        -- Try the more flexible state-scanner first (variable-sized frames)
        if setupStateScanAnimation(player, cfg, image) then
            return true
        end

        -- If scanning failed, try the conventional grid approach:
        local stateRows = cfg.stateRows or { idle = 1, run = 2, dash = 3 }
        local stateCounts = cfg.stateFrameCounts or { idle = 5, run = 6, dash = 4 }
        local frameW, frameH = ensureFrameSize(cfg, image, stateCounts, stateRows)
        if not (frameW and frameH) then
            -- not enough info to build grid frames
            return false
        end

        local grid = Anim8.newGrid(
            frameW,
            frameH,
            image:getWidth(),
            image:getHeight(),
            cfg.frameLeft,
            cfg.frameTop,
            cfg.frameSpacing
        )

        local durations = cfg.stateFrameDurations or {}
        local idleDuration = durations.idle or cfg.frameDuration or 0.12
        local runDuration = durations.run or cfg.frameDuration or 0.10
        local dashDuration = durations.dash or cfg.frameDuration or 0.08

        player.sprite = image
        player.frameW = frameW
        player.frameH = frameH
        player.animMode = "state"
        player.animations = {
            idle = Anim8.newAnimation(grid(buildRange(stateCounts.idle), stateRows.idle or 1), idleDuration),
            run = Anim8.newAnimation(grid(buildRange(stateCounts.run), stateRows.run or 2), runDuration),
            dash = Anim8.newAnimation(grid(buildRange(stateCounts.dash), stateRows.dash or 3), dashDuration)
        }

        player.anim = player.animations.idle
        local baseSize = math.max(frameW, frameH)
        local size = cfg.size or 35
        player.scale = size / baseSize
        player.pixelPerfect = cfg.pixelPerfect ~= false

        return true
    end

    -- directional animations (grid required)
    if not (cfg.frameWidth and cfg.frameHeight) then
        -- directional mode requires explicit frame dimensions
        return false
    end

    local grid = Anim8.newGrid(
        cfg.frameWidth,
        cfg.frameHeight,
        image:getWidth(),
        image:getHeight(),
        cfg.frameLeft,
        cfg.frameTop,
        cfg.frameSpacing
    )

    local cols = cfg.frameCols or "1-4"
    local rows = cfg.frameRows or {
        down = 1,
        left = 2,
        right = 3,
        up = 4
    }

    local duration = cfg.frameDuration or 0.12
    player.sprite = image
    player.frameW = cfg.frameWidth
    player.frameH = cfg.frameHeight
    player.animMode = "directional"
    player.animations = {
        down = Anim8.newAnimation(grid(cols, rows.down or 1), duration),
        left = Anim8.newAnimation(grid(cols, rows.left or 2), duration),
        right = Anim8.newAnimation(grid(cols, rows.right or 3), duration),
        up = Anim8.newAnimation(grid(cols, rows.up or 4), duration)
    }

    local defaultAnim = cfg.defaultAnim or "right"
    player.anim = player.animations[defaultAnim] or player.animations.right or player.animations.down

    local baseSize = math.max(cfg.frameWidth, cfg.frameHeight)
    local size = cfg.size or 35
    player.scale = size / baseSize
    player.pixelPerfect = cfg.pixelPerfect ~= false

    return true
end

-- Public constructor:
-- config options (commonly used):
--  - x, y: initial position
--  - speed, moveStartSpeed, moveRampDuration, dashSpeed, dashDuration, dashCooldown
--  - dashSoundPath: path to dash SFX (string)
--  - maxHealth/health, maxEnergy/energy
--  - spritePath, animMode, frameWidth/frameHeight (see setupGridAnimation)
--  - stateRows, stateFrameCounts, stateFrameDurations, frameDuration
--  - size: desired "logical" size (player.scale is computed so the largest frame fits this size)
--  - pixelPerfect: if false, will not round draw position
function Player.new(config)
    local cfg = config or {}
    local player = {
        x = cfg.x or 0,
        y = cfg.y or 0,

        -- movement / dash mechanics
        speed = cfg.speed or 300,
        moveStartSpeed = cfg.moveStartSpeed or ((cfg.speed or 300) * 0.35),
        moveRampDuration = cfg.moveRampDuration or 0.45,
        moveHeldTime = 0,
        dashSpeed = cfg.dashSpeed or ((cfg.speed or 300) * 2.5),
        dashDuration = cfg.dashDuration or 0.18,
        dashCooldown = cfg.dashCooldown or 5.0,
        dashTimer = 0,
        dashCooldownTimer = 0,
        isDashing = false,
        -- Stored on the entity so the movement system can trigger the correct dash SFX.
        dashSoundPath = cfg.dashSoundPath or "assets/audio/sfx/Dash.wav",

        -- health / energy
        maxHealth = cfg.maxHealth or 100,
        health = cfg.health or 100,
        maxEnergy = cfg.maxEnergy or 100,
        energy = cfg.energy or 100
    }

    -- Try to set up Anim8-driven animations (grid or state scanning). If successful, return player.
    if setupGridAnimation(player, cfg) then
        return player
    end

    -- Fallback: use SpriteSheet builder (assumes a separate SpriteSheet utility produces frames with w/h/quad)
    local sheet = SpriteSheet.buildFrames(cfg.spritePath or "assets/sprites/player/Robot.png")
    local frames = sheet.frames

    -- compute maximum frame size to derive scale (so the desired `cfg.size` fits)
    local maxW = 0
    local maxH = 0
    for _, frame in ipairs(frames) do
        if frame.w > maxW then
            maxW = frame.w
        end
        if frame.h > maxH then
            maxH = frame.h
        end
    end

    local baseSize = math.max(1, math.max(maxW, maxH))
    local size = cfg.size or 35
    local scale = size / baseSize

    player.sprite = sheet.image
    player.sprite:setFilter("nearest", "nearest") -- pixel art: nearest filter avoids blur
    player.frames = frames
    player.frameIndex = 1
    player.frameTimer = 0
    player.frameDuration = cfg.frameDuration or 0.12
    player.scale = scale
    player.pixelPerfect = cfg.pixelPerfect ~= false

    return player
end

-- advances animations based on the player's state / input flags.
-- this function only updates animations - movement & physics are handled elsewhere.
function Player.update(player, dt)
    if not player then
        return
    end

    -- Anim8 "state" mode (named states: idle/run/dash)
    if player.animMode == "state" and player.animations then
        local isMoving = player.isMoving or false

        -- Priority: dash animation when dashing, otherwise run if moving, otherwise idle
        if player.isDashing and player.animations.dash then
            -- restart dash animation if not already set
            if player.anim ~= player.animations.dash then
                player.animations.dash:gotoFrame(1)
            end
            player.anim = player.animations.dash
        elseif isMoving and player.animations.run then
            player.anim = player.animations.run
        elseif player.animations.idle then
            player.anim = player.animations.idle
        end

        if player.anim then
            player.anim:update(dt)
        end
        return
    end

    -- Anim8 "directional" mode (choose animation based on movement vector)
    if player.animations and player.anim then
        local moveX = player.moveX or 0
        local moveY = player.moveY or 0
        local isMoving = player.isMoving or (moveX ~= 0 or moveY ~= 0)

        if isMoving then
            local absX = math.abs(moveX)
            local absY = math.abs(moveY)
            -- choose the dominant axis to pick direction (X overrides Y when equal)
            if absX >= absY then
                if moveX > 0 then
                    player.anim = player.animations.right
                elseif moveX < 0 then
                    player.anim = player.animations.left
                end
            else
                if moveY > 0 then
                    player.anim = player.animations.down
                elseif moveY < 0 then
                    player.anim = player.animations.up
                end
            end
            player.anim:update(dt)
        else
            -- Not moving: show a consistent "idle" frame, using frame 2 as a default stand pose
            player.anim:gotoFrame(2)
        end
        return
    end

    -- Fallback simple frame cycling (no Anim8)
    if not player.frames or #player.frames <= 1 then
        return
    end

    player.frameTimer = player.frameTimer + dt
    if player.frameTimer >= player.frameDuration then
        player.frameTimer = player.frameTimer - player.frameDuration
        player.frameIndex = (player.frameIndex % #player.frames) + 1
    end
end

-- Draw the player centered on its logical position.
-- If pixelPerfect is true (default), positions are rounded to avoid subpixel blurring for pixel art.
function Player.draw(player)
    if not player then
        return
    end

    local drawX = player.x
    local drawY = player.y
    if player.pixelPerfect then
        -- round to nearest integer for crisp pixel rendering
        drawX = math.floor(drawX + 0.5)
        drawY = math.floor(drawY + 0.5)
    end

    love.graphics.setColor(1, 1, 1)
    -- Anim8-driven drawing path
    if player.anim then
        local frame = player.anim:getFrame()
        local ox = 0
        local oy = 0
        if frame then
            -- Anim8 frame entries in our setup include w/h so we can center the sprite
            ox = frame.w / 2
            oy = frame.h / 2
        end
        -- Anim8 animation.draw(sprite, x, y, rotation, sx, sy, ox, oy)
        player.anim:draw(player.sprite, drawX, drawY, 0, player.scale, player.scale, ox, oy)
        return
    end

    -- Fallback draw using SpriteSheet frames (quad-based)
    local frame = player.frames and player.frames[player.frameIndex]
    if frame then
        love.graphics.draw(
            player.sprite,
            frame.quad,
            drawX,
            drawY,
            0,
            player.scale,
            player.scale,
            frame.w / 2,
            frame.h / 2
        )
    else
        -- As a last resort, draw the whole sprite at the position
        love.graphics.draw(player.sprite, drawX, drawY)
    end
end

return Player
