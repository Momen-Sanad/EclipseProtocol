local SpriteSheet = require("src/utils/sprite_sheet")
local Anim8 = require("anim8.anim8")

local Player = {}

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

local function buildRange(count)
    return "1-" .. tostring(count)
end

local function ensureFrameSize(cfg, image, stateCounts, stateRows)
    local frameW = cfg.frameWidth
    local frameH = cfg.frameHeight

    if not frameW then
        local maxCols = maxKeyValue(stateCounts)
        if maxCols > 0 then
            frameW = image:getWidth() / maxCols
        end
    end

    if not frameH then
        local rowCount = maxKeyValue(stateRows)
        if rowCount > 0 then
            frameH = image:getHeight() / rowCount
        end
    end

    return frameW, frameH
end

local function buildSegments(imageData, isRow, alphaCutoff, emptyThreshold)
    local w, h = imageData:getDimensions()
    local segments = {}
    local major = isRow and h or w
    local minor = isRow and w or h
    local start = nil

    for i = 0, major - 1 do
        local transparent = 0
        for j = 0, minor - 1 do
            local x = isRow and j or i
            local y = isRow and i or j
            local _, _, _, a = imageData:getPixel(x, y)
            if a <= alphaCutoff then
                transparent = transparent + 1
            end
        end

        local empty = (transparent / minor) >= emptyThreshold
        if not empty and start == nil then
            start = i
        elseif empty and start ~= nil then
            table.insert(segments, { start, i - 1 })
            start = nil
        end
    end

    if start ~= nil then
        table.insert(segments, { start, major - 1 })
    end

    return segments
end

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

local function setupStateScanAnimation(player, cfg, image)
    local spritePath = cfg.spritePath or "assets/sprites/player/Robot.png"
    local imageData = love.image.newImageData(spritePath)
    local imageW = imageData:getWidth()
    local imageH = imageData:getHeight()

    local alphaCutoff = cfg.alphaCutoff or 0.05
    local rowEmpty = cfg.rowEmptyThreshold or 0.98
    local colEmpty = cfg.colEmptyThreshold or 0.98

    local rowSegments = buildSegments(imageData, true, alphaCutoff, rowEmpty)
    if #rowSegments == 0 then
        return false
    end

    local stateOrder = cfg.stateOrder or { "idle", "run", "dash" }
    local stateRows = cfg.stateRows or {}
    local stateCounts = cfg.stateFrameCounts or {}
    local durations = cfg.stateFrameDurations or {}
    local defaultDuration = cfg.frameDuration or 0.12

    local maxW, maxH = 0, 0
    player.sprite = image
    player.animMode = "state"
    player.animations = {}

    for index, stateName in ipairs(stateOrder) do
        local rowIndex = stateRows[stateName] or index
        local rowSeg = rowSegments[rowIndex]
        if not rowSeg then
            return false
        end

        local colSegments = buildRowFrames(imageData, rowSeg, alphaCutoff, colEmpty)
        local expected = stateCounts[stateName]
        if expected and #colSegments < expected then
            return false
        end
        if #colSegments == 0 then
            return false
        end

        if expected and #colSegments > expected then
            local trimmed = {}
            for i = 1, expected do
                trimmed[#trimmed + 1] = colSegments[i]
            end
            colSegments = trimmed
        end

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

    player.anim = player.animations.idle or player.animations.run or player.animations.dash

    local baseSize = math.max(1, math.max(maxW, maxH))
    local size = cfg.size or 35
    player.scale = size / baseSize
    player.frameW = maxW
    player.frameH = maxH
    player.pixelPerfect = cfg.pixelPerfect ~= false

    return true
end

local function setupGridAnimation(player, cfg)
    local image = love.graphics.newImage(cfg.spritePath or "assets/sprites/player/Robot.png")
    image:setFilter("nearest", "nearest")
    local animMode = cfg.animMode or "directional"

    if animMode == "state" then
        if setupStateScanAnimation(player, cfg, image) then
            return true
        end
        local stateRows = cfg.stateRows or { idle = 1, run = 2, dash = 3 }
        local stateCounts = cfg.stateFrameCounts or { idle = 5, run = 6, dash = 4 }
        local frameW, frameH = ensureFrameSize(cfg, image, stateCounts, stateRows)
        if not (frameW and frameH) then
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

    if not (cfg.frameWidth and cfg.frameHeight) then
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

function Player.new(config)
    local cfg = config or {}
    local player = {
        x = cfg.x or 0,
        y = cfg.y or 0,
        speed = cfg.speed or 300,
        dashSpeed = cfg.dashSpeed or ((cfg.speed or 300) * 2.5),
        dashDuration = cfg.dashDuration or 0.18,
        dashCooldown = cfg.dashCooldown or 5.0,
        dashTimer = 0,
        dashCooldownTimer = 0,
        isDashing = false,
        dashSoundPath = cfg.dashSoundPath or "assets/audio/sfx/Dash.wav",
        maxHealth = cfg.maxHealth or 100,
        health = cfg.health or 100,
        maxEnergy = cfg.maxEnergy or 100,
        energy = cfg.energy or 100
    }

    if setupGridAnimation(player, cfg) then
        return player
    end

    local sheet = SpriteSheet.buildFrames(cfg.spritePath or "assets/sprites/player/Robot.png")
    local frames = sheet.frames

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
    player.sprite:setFilter("nearest", "nearest")
    player.frames = frames
    player.frameIndex = 1
    player.frameTimer = 0
    player.frameDuration = cfg.frameDuration or 0.12
    player.scale = scale
    player.pixelPerfect = cfg.pixelPerfect ~= false

    return player
end

function Player.update(player, dt)
    if not player then
        return
    end

    if player.animMode == "state" and player.animations then
        local isMoving = player.isMoving or false
        if player.isDashing and player.animations.dash then
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

    if player.animations and player.anim then
        local moveX = player.moveX or 0
        local moveY = player.moveY or 0
        local isMoving = player.isMoving or (moveX ~= 0 or moveY ~= 0)

        if isMoving then
            local absX = math.abs(moveX)
            local absY = math.abs(moveY)
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
            player.anim:gotoFrame(2)
        end
        return
    end

    if not player.frames or #player.frames <= 1 then
        return
    end

    player.frameTimer = player.frameTimer + dt
    if player.frameTimer >= player.frameDuration then
        player.frameTimer = player.frameTimer - player.frameDuration
        player.frameIndex = (player.frameIndex % #player.frames) + 1
    end
end

function Player.draw(player)
    if not player then
        return
    end

    local drawX = player.x
    local drawY = player.y
    if player.pixelPerfect then
        drawX = math.floor(drawX + 0.5)
        drawY = math.floor(drawY + 0.5)
    end

    love.graphics.setColor(1, 1, 1)
    if player.anim then
        local frame = player.anim:getFrame()
        local ox = 0
        local oy = 0
        if frame then
            ox = frame.w / 2
            oy = frame.h / 2
        end
        player.anim:draw(player.sprite, drawX, drawY, 0, player.scale, player.scale, ox, oy)
        return
    end

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
        love.graphics.draw(player.sprite, drawX, drawY)
    end
end

return Player
